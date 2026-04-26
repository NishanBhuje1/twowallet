class Household {
  final String id;
  final String? name;
  final double splitRatioA;
  final double? splitRatioB;
  final String splitMethod;
  final double privatePocketAAud;
  final double privatePocketBAud;
  final String subscriptionTier;
  final String status;
  final String? pausedAt;
  final String? resumedAt;
  final String? pauseReason;
  final String? createdAt;

  // New Fields
  final int moneyDateDay; // 0 = Sunday, etc.
  final int moneyDateHour; // 24-hour format

  const Household({
    required this.id,
    this.name,
    this.splitRatioA = 0.5,
    this.splitRatioB,
    this.splitMethod = 'fifty_fifty',
    this.privatePocketAAud = 200,
    this.privatePocketBAud = 200,
    this.subscriptionTier = 'free',
    this.status = 'active',
    this.pausedAt,
    this.resumedAt,
    this.pauseReason,
    this.createdAt,
    // New Defaults
    this.moneyDateDay = 0,
    this.moneyDateHour = 18,
  });

  bool get isPaused => status == 'paused';

  factory Household.fromJson(Map<String, dynamic> j) => Household(
        id: j['id'] as String,
        name: j['name'] as String?,
        splitRatioA: double.parse((j['split_ratio_a'] ?? 0.5).toString()),
        splitRatioB: j['split_ratio_b'] != null
            ? double.parse(j['split_ratio_b'].toString())
            : null,
        splitMethod: j['split_method'] as String? ?? 'fifty_fifty',
        privatePocketAAud:
            double.parse((j['private_pocket_a_aud'] ?? 200).toString()),
        privatePocketBAud:
            double.parse((j['private_pocket_b_aud'] ?? 200).toString()),
        subscriptionTier: j['subscription_tier'] as String? ?? 'free',
        status: j['status'] as String? ?? 'active',
        pausedAt: j['paused_at'] as String?,
        resumedAt: j['resumed_at'] as String?,
        pauseReason: j['pause_reason'] as String?,
        createdAt: j['created_at'] as String?,
        // New JSON mapping
        moneyDateDay: (j['money_date_day'] as num?)?.toInt() ?? 0,
        moneyDateHour: (j['money_date_hour'] as num?)?.toInt() ?? 18,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'split_ratio_a': splitRatioA,
        'split_ratio_b': splitRatioB,
        'split_method': splitMethod,
        'private_pocket_a_aud': privatePocketAAud,
        'private_pocket_b_aud': privatePocketBAud,
        'subscription_tier': subscriptionTier,
        'status': status,
        'paused_at': pausedAt,
        'resumed_at': resumedAt,
        'pause_reason': pauseReason,
        'created_at': createdAt,
        // New Map entries
        'money_date_day': moneyDateDay,
        'money_date_hour': moneyDateHour,
      };
}
