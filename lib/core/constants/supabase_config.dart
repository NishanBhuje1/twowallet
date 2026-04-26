class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Call once in main() before Supabase.initialize().
  /// Throws at startup — not silently at runtime — if either key is missing.
  static void assertConfigured() {
    assert(url.isNotEmpty,
        'SUPABASE_URL is not set. Pass --dart-define=SUPABASE_URL=<value> at build time.');
    assert(anonKey.isNotEmpty,
        'SUPABASE_ANON_KEY is not set. Pass --dart-define=SUPABASE_ANON_KEY=<value> at build time.');
  }
}
