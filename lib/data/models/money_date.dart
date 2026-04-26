class MoneyDate {
  final String id;
  final String householdId;
  final String weekStart;
  final List<String> talkingPoints;
  final String? decisionPrompt;
  final Map<String, dynamic> weekInNumbers;
  final bool completedByA;
  final bool completedByB;
  final String? completedAt;
  final String? createdAt;

  const MoneyDate({
    required this.id,
    required this.householdId,
    required this.weekStart,
    this.talkingPoints = const [],
    this.decisionPrompt,
    this.weekInNumbers = const {},
    this.completedByA = false,
    this.completedByB = false,
    this.completedAt,
    this.createdAt,
  });

  factory MoneyDate.fromJson(Map<String, dynamic> j) => MoneyDate(
    id: j['id'] as String,
    householdId: j['household_id'] as String,
    weekStart: j['week_start'] as String,
    talkingPoints: (j['talking_points'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? [],
    decisionPrompt: j['decision_prompt'] as String?,
    weekInNumbers: (j['week_in_numbers'] as Map<String, dynamic>?) ?? {},
    completedByA: j['completed_by_a'] as bool? ?? false,
    completedByB: j['completed_by_b'] as bool? ?? false,
    completedAt: j['completed_at'] as String?,
    createdAt: j['created_at'] as String?,
  );
}