import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';

class GoalContribution {
  final String id;
  final String goalId;
  final String partnerId;
  final double amountAud;
  final String date;
  final String? notes;

  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.partnerId,
    required this.amountAud,
    required this.date,
    this.notes,
  });

  factory GoalContribution.fromJson(Map<String, dynamic> j) => GoalContribution(
    id: j['id'] as String,
    goalId: j['goal_id'] as String,
    partnerId: j['partner_id'] as String,
    amountAud: double.parse(j['amount_aud'].toString()),
    date: j['date'] as String,
    notes: j['notes'] as String?,
  );
}

class GoalRepository {
  final _client = Supabase.instance.client;

  Future<List<Goal>> fetchActiveGoals() async {
    final data = await _client
        .from('goals')
        .select()
        .eq('is_active', true)
        .order('created_at');

    return data.map((e) => Goal.fromJson(e)).toList();
  }

  Future<List<GoalContribution>> fetchContributions(String goalId) async {
    final data = await _client
        .from('goal_contributions')
        .select()
        .eq('goal_id', goalId)
        .order('date', ascending: false);

    return data.map((e) => GoalContribution.fromJson(e)).toList();
  }

  Future<Map<String, double>> fetchTotalsPerPartner(String goalId) async {
    final contributions = await fetchContributions(goalId);
    final Map<String, double> totals = {};
    for (final c in contributions) {
      totals[c.partnerId] = (totals[c.partnerId] ?? 0) + c.amountAud;
    }
    return totals;
  }

  Future<Goal> createGoal({
    required String householdId,
    required String name,
    required double targetAmountAud,
    String? emoji,
    String? targetDate,
    String contributionSplit = 'fifty_fifty',
    double contributionRatioA = 0.5,
  }) async {
    final data = await _client
        .from('goals')
        .insert({
          'household_id': householdId,
          'name': name,
          'emoji': emoji,
          'target_amount_aud': targetAmountAud,
          'target_date': targetDate,
          'contribution_split': contributionSplit,
          'contribution_ratio_a': contributionRatioA,
          'is_active': true,
        })
        .select()
        .single();

    return Goal.fromJson(data);
  }

  Future<void> addContribution({
    required String goalId,
    required String partnerId,
    required double amountAud,
    String? notes,
  }) async {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await _client.from('goal_contributions').insert({
      'goal_id': goalId,
      'partner_id': partnerId,
      'amount_aud': amountAud,
      'date': dateStr,
      'notes': notes,
    });
  }

  Future<void> updateGoal({
    required String goalId,
    required String name,
    required double targetAmountAud,
    String? emoji,
    String? targetDate,
  }) async {
    await _client.from('goals').update({
      'name': name,
      'emoji': emoji,
      'target_amount_aud': targetAmountAud,
      'target_date': targetDate,
    }).eq('id', goalId);
  }

  Future<void> archiveGoal(String goalId) async {
    await _client
        .from('goals')
        .update({'is_active': false})
        .eq('id', goalId);
  }
}