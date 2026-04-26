/// Type-safe constants for values stored in and returned from Supabase.
/// Replaces the 40+ magic string literals scattered across the codebase.

enum Bucket {
  mine,
  ours,
  theirs;

  /// The exact string stored in the `bucket` column.
  String get value => name; // 'mine', 'ours', 'theirs'

  static Bucket? fromValue(String? s) {
    if (s == null) return null;
    return values.where((b) => b.value == s).firstOrNull;
  }
}

enum PartnerRole {
  partnerA,
  partnerB;

  /// The exact string stored in the `role` column.
  String get value => switch (this) {
        partnerA => 'partner_a',
        partnerB => 'partner_b',
      };

  static PartnerRole? fromValue(String? s) {
    if (s == null) return null;
    return values.where((r) => r.value == s).firstOrNull;
  }
}
