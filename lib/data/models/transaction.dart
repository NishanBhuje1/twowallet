class Transaction {
  final String id;
  final String householdId;
  final String accountId;
  final String partnerId;
  final String bucket;
  final double amountAud;
  final String merchantName;
  final String? category;
  final String date;
  final bool isPrivate;
  final bool isIncome;
  final bool isRecurring;
  final String? basiqTransactionId;
  final String? notes;
  final String? createdAt;

  const Transaction({
    required this.id,
    required this.householdId,
    required this.accountId,
    required this.partnerId,
    required this.bucket,
    required this.amountAud,
    required this.merchantName,
    this.category,
    required this.date,
    this.isPrivate = false,
    this.isIncome = false,
    this.isRecurring = false,
    this.basiqTransactionId,
    this.notes,
    this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id: j['id'] as String,
    householdId: j['household_id'] as String,
    accountId: j['account_id'] as String,
    partnerId: j['partner_id'] as String,
    bucket: j['bucket'] as String,
    amountAud: double.parse(j['amount_aud'].toString()),
    merchantName: j['merchant_name'] as String,
    category: j['category'] as String?,
    date: j['date'] as String,
    isPrivate: j['is_private'] as bool? ?? false,
    isIncome: j['is_income'] as bool? ?? false,
    isRecurring: j['is_recurring'] as bool? ?? false,
    basiqTransactionId: j['basiq_transaction_id'] as String?,
    notes: j['notes'] as String?,
    createdAt: j['created_at'] as String?,
  );
}