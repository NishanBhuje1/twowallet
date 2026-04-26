class Goal {
  final String id;
  final String householdId;
  final String name;
  final String? emoji;
  final double targetAmountAud;
  final String? targetDate;
  final String contributionSplit;
  final double contributionRatioA;
  final String? linkedAccountId;
  final bool isActive;
  final String? createdAt;

  const Goal({
    required this.id,
    required this.householdId,
    required this.name,
    this.emoji,
    required this.targetAmountAud,
    this.targetDate,
    this.contributionSplit = 'fifty_fifty',
    this.contributionRatioA = 0.5,
    this.linkedAccountId,
    this.isActive = true,
    this.createdAt,
  });

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'] as String,
    householdId: j['household_id'] as String,
    name: j['name'] as String,
    emoji: j['emoji'] as String?,
    targetAmountAud: double.parse(j['target_amount_aud'].toString()),
    targetDate: j['target_date'] as String?,
    contributionSplit: j['contribution_split'] as String? ?? 'fifty_fifty',
    contributionRatioA: double.parse((j['contribution_ratio_a'] ?? 0.5).toString()),
    linkedAccountId: j['linked_account_id'] as String?,
    isActive: j['is_active'] as bool? ?? true,
    createdAt: j['created_at'] as String?,
  );
}