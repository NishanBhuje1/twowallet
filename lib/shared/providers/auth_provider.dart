import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/partner.dart';
import 'repo_providers.dart';

// Current auth user
final authUserProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange
      .map((state) => state.session?.user);
});

// Auth service
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// Current partners in the household — uses the shared householdRepoProvider
// so the same HouseholdRepository instance (and its householdId cache) is reused
// across auth_provider and all feature providers.
final partnersProvider = FutureProvider<List<Partner>>((ref) async {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return [];
  return ref.read(householdRepoProvider).fetchPartners();
});

// Which partner is the current user
final myPartnerProvider = FutureProvider<Partner?>((ref) async {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return null;
  final partners = await ref.watch(partnersProvider.future);
  return partners.where((p) => p.userId == user.id).firstOrNull;
});