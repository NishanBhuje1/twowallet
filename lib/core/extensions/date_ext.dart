extension SupabaseDateExt on DateTime {
  /// Formats the date as `YYYY-MM-DD` — the string format used in every
  /// Supabase `date` column filter. Replaces the manual padLeft() expressions
  /// scattered across the repository layer.
  String toSupabaseDate() =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
