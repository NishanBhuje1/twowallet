import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../data/models/goal.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../fair_split/providers/fair_split_provider.dart';

final goalRepoProvider = Provider((_) => GoalRepository());

final goalsProvider = FutureProvider<List<Goal>>((ref) async {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return [];
  return ref.read(goalRepoProvider).fetchActiveGoals();
});

// Contributions totals per goal — map of goalId -> {partnerId -> total}
final goalContributionTotalsProvider =
    FutureProvider.family<Map<String, double>, String>((ref, goalId) {
  return ref.read(goalRepoProvider).fetchTotalsPerPartner(goalId);
});

class GoalsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addContribution({
    required String goalId,
    required double amountAud,
    String? notes,
  }) async {
    final partners = await ref.read(partnersProvider.future);
    final userId = ref.read(authUserProvider).value?.id;
    final me = partners.where((p) => p.userId == userId).firstOrNull;
    if (me == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(goalRepoProvider).addContribution(
        goalId: goalId,
        partnerId: me.id,
        amountAud: amountAud,
        notes: notes,
      );
      ref.invalidate(goalsProvider);
      ref.invalidate(goalContributionTotalsProvider(goalId));
    });
  }

  Future<void> updateGoal({
    required String goalId,
    required String name,
    required double targetAmountAud,
    String? emoji,
    String? targetDate,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(goalRepoProvider).updateGoal(
        goalId: goalId,
        name: name,
        targetAmountAud: targetAmountAud,
        emoji: emoji,
        targetDate: targetDate,
      );
      ref.invalidate(goalsProvider);
    });
  }

  Future<void> deleteGoal(String goalId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(goalRepoProvider).archiveGoal(goalId);
      ref.invalidate(goalsProvider);
    });
  }

  Future<void> createGoal({
    required String name,
    required double targetAmountAud,
    String? emoji,
    String? targetDate,
    String contributionSplit = 'fifty_fifty',
    double contributionRatioA = 0.5,
  }) async {
    final partners = await ref.read(partnersProvider.future);
    if (partners.isEmpty) return;
    final householdId = partners.first.householdId;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(goalRepoProvider).createGoal(
        householdId: householdId,
        name: name,
        targetAmountAud: targetAmountAud,
        emoji: emoji,
        targetDate: targetDate,
        contributionSplit: contributionSplit,
        contributionRatioA: contributionRatioA,
      );
      ref.invalidate(goalsProvider);
    });
  }
}

final goalsNotifierProvider =
    AsyncNotifierProvider<GoalsNotifier, void>(GoalsNotifier.new);