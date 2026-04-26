class Account {
  final String id;
  final String householdId;
  final String? partnerId;
  final String bucket;
  final String? basiqAccountId;
  final String institutionName;
  final String accountName;
  final String accountType;
  final double balanceAud;
  final bool isLiability;
  final String? lastSyncedAt;
  final bool isManual;

  const Account({
    required this.id,
    required this.householdId,
    this.partnerId,
    required this.bucket,
    this.basiqAccountId,
    required this.institutionName,
    required this.accountName,
    required this.accountType,
    this.balanceAud = 0,
    this.isLiability = false,
    this.lastSyncedAt,
    this.isManual = false,
  });

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    id: j['id'] as String,
    householdId: j['household_id'] as String,
    partnerId: j['partner_id'] as String?,
    bucket: j['bucket'] as String,
    basiqAccountId: j['basiq_account_id'] as String?,
    institutionName: j['institution_name'] as String,
    accountName: j['account_name'] as String,
    accountType: j['account_type'] as String,
    balanceAud: double.parse((j['balance_aud'] ?? 0).toString()),
    isLiability: j['is_liability'] as bool? ?? false,
    lastSyncedAt: j['last_synced_at'] as String?,
    isManual: j['is_manual'] as bool? ?? false,
  );
}