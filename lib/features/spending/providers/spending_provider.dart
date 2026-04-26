import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../data/models/transaction.dart';
import '../../fair_split/providers/fair_split_provider.dart';
import '../../../shared/providers/auth_provider.dart';

final selectedBucketProvider = StateProvider<String?>((ref) => null);

final spendingTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return [];
  return ref.read(transactionRepoProvider).fetchThisMonthAll();
});

final filteredTransactionsProvider =
    Provider<AsyncValue<List<Transaction>>>((ref) {
  final allAsync = ref.watch(spendingTransactionsProvider);
  final bucket = ref.watch(selectedBucketProvider);

  return allAsync.whenData((txs) {
    if (bucket == null) return txs;
    return txs.where((t) => t.bucket == bucket).toList();
  });
});
