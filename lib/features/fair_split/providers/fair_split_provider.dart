import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/settlement.dart';
import '../../../data/models/household.dart';
import '../../../core/utils/fair_split_calc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/repo_providers.dart';
import '../../home/providers/home_provider.dart';

export '../../../shared/providers/repo_providers.dart'
    show transactionRepoProvider, settlementRepoProvider, householdRepoProvider;

// Raw data providers
// Filters 'ours' from the shared monthly cache instead of making its own query.
// When home screen has already loaded, this is free (zero network calls).
final oursTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final all = await ref.watch(allTransactionsThisMonthProvider.future);
  return all.where((t) => t.bucket == Bucket.ours.value).toList();
});

final settlementHistoryProvider = FutureProvider<List<Settlement>>((ref) {
  return ref.read(settlementRepoProvider).fetchHistory();
});

final householdProvider = FutureProvider<Household?>((ref) {
  return ref.read(householdRepoProvider).fetchMyHousehold();
});

// The core derived provider — computes the settlement from real data
final fairSplitResultProvider = FutureProvider<FairSplitResult?>((ref) async {
  final transactions = await ref.watch(oursTransactionsProvider.future);
  final household = await ref.watch(householdProvider.future);
  final partners = await ref.watch(partnersProvider.future);

  if (household == null || partners.length < 2) return null;

  final partnerA = partners.where((p) => p.role == PartnerRole.partnerA.value).firstOrNull;
  final partnerB = partners.where((p) => p.role == PartnerRole.partnerB.value).firstOrNull;

  if (partnerA == null || partnerB == null) return null;

  return FairSplitCalc.calculate(
    oursTransactions: transactions,
    splitRatioA: household.splitRatioA,
    partnerAId: partnerA.id,
    partnerBId: partnerB.id,
  );
});

// Notifier to handle settling up
class SettlementNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> settle({
    required String householdId,
    required double amountAud,
    required String fromPartnerId,
    required String toPartnerId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(settlementRepoProvider).saveSettlement(
        householdId: householdId,
        amountAud: amountAud,
        fromPartnerId: fromPartnerId,
        toPartnerId: toPartnerId,
      );
      // Invalidate so UI refreshes
      ref.invalidate(oursTransactionsProvider);
      ref.invalidate(settlementHistoryProvider);
    });
  }
}

final settlementNotifierProvider =
    AsyncNotifierProvider<SettlementNotifier, void>(SettlementNotifier.new);