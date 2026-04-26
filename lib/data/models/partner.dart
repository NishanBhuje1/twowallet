class Partner {
  final String id;
  final String householdId;
  final String userId;
  final String displayName;
  final String role;
  final double? monthlyIncomeNetAud;
  final bool incomeVisibleToPartner;
  final String? basiqUserId;
  final String? createdAt;

  const Partner({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.displayName,
    required this.role,
    this.monthlyIncomeNetAud,
    this.incomeVisibleToPartner = false,
    this.basiqUserId,
    this.createdAt,
  });

  factory Partner.fromJson(Map<String, dynamic> j) => Partner(
    id: j['id'] as String,
    householdId: j['household_id'] as String,
    userId: j['user_id'] as String,
    displayName: j['display_name'] as String,
    role: j['role'] as String,
    monthlyIncomeNetAud: j['monthly_income_net_aud'] != null
        ? double.parse(j['monthly_income_net_aud'].toString())
        : null,
    incomeVisibleToPartner: j['income_visible_to_partner'] as bool? ?? false,
    basiqUserId: j['basiq_user_id'] as String?,
    createdAt: j['created_at'] as String?,
  );
}