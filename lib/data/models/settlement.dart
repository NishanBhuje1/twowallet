class Settlement {
  final String id;
  final String householdId;
  final String month;
  final double amountAud;
  final String fromPartnerId;
  final String toPartnerId;
  final bool settled;
  final String? settledAt;

  const Settlement({
    required this.id,
    required this.householdId,
    required this.month,
    required this.amountAud,
    required this.fromPartnerId,
    required this.toPartnerId,
    this.settled = false,
    this.settledAt,
  });

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        id: j['id'] as String,
        householdId: j['household_id'] as String,
        month: j['month'] as String,
        amountAud: double.parse(j['amount_aud'].toString()),
        fromPartnerId: j['from_partner_id'] as String,
        toPartnerId: j['to_partner_id'] as String,
        settled: j['settled'] as bool? ?? false,
        settledAt: j['settled_at'] as String?,
      );
}
