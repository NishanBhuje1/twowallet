import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/household.dart';
import '../models/partner.dart';

class HouseholdRepository {
  final _client = Supabase.instance.client;

  // Cached per logged-in user so every update method avoids a redundant
  // partners→householdId round-trip. Invalidated when the user changes.
  String? _cachedHouseholdId;
  String? _cachedUserId;

  /// Returns the householdId for the current user, using an in-memory cache.
  /// Returns null when no user is logged in.
  Future<String?> _getHouseholdId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _cachedHouseholdId = null;
      _cachedUserId = null;
      return null;
    }
    // Invalidate if a different user has signed in since last call.
    if (_cachedUserId != userId) {
      _cachedHouseholdId = null;
      _cachedUserId = userId;
    }
    if (_cachedHouseholdId != null) return _cachedHouseholdId;

    final row = await _client
        .from('partners')
        .select('household_id')
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();

    _cachedHouseholdId = row?['household_id'] as String?;
    return _cachedHouseholdId;
  }

  Future<Household?> fetchMyHousehold() async {
    final householdId = await _getHouseholdId();
    if (householdId == null) return null;

    final row = await _client
        .from('households')
        .select()
        .eq('id', householdId)
        .maybeSingle();

    return row != null ? Household.fromJson(row) : null;
  }

  Future<List<Partner>> fetchPartners() async {
    final householdId = await _getHouseholdId();
    if (householdId == null) return [];

    final data = await _client
        .from('partners')
        .select()
        .eq('household_id', householdId)
        .order('role');

    return data.map((e) => Partner.fromJson(e)).toList();
  }

  Future<void> updateSplitRatio(double ratioA) async {
    final id = await _getHouseholdId();
    if (id == null) return;
    await _client.from('households').update({'split_ratio_a': ratioA}).eq('id', id);
  }

  Future<void> updateSplitMethod(String method) async {
    final id = await _getHouseholdId();
    if (id == null) return;
    await _client.from('households').update({'split_method': method}).eq('id', id);
  }

  Future<void> updatePrivatePockets({
    required double pocketA,
    required double pocketB,
  }) async {
    final id = await _getHouseholdId();
    if (id == null) return;
    await _client.from('households').update({
      'private_pocket_a_aud': pocketA,
      'private_pocket_b_aud': pocketB,
    }).eq('id', id);
  }

  Future<void> pauseHousehold({
    required String householdId,
    required String partnerId,
    String? reason,
  }) async {
    await _client.from('households').update({
      'status': 'paused',
      'paused_at': DateTime.now().toIso8601String(),
      'pause_reason': reason,
    }).eq('id', householdId);

    await _client.from('household_events').insert({
      'household_id': householdId,
      'event_type': 'paused',
      'initiated_by': partnerId,
      'note': reason,
    });

    await _client
        .from('goals')
        .update({'status': 'paused'})
        .eq('household_id', householdId)
        .eq('status', 'active');
  }

  Future<void> updateMoneyDateSchedule({
    required int day,
    required int hour,
  }) async {
    final id = await _getHouseholdId();
    if (id == null) return;
    await _client.from('households').update({
      'money_date_day': day,
      'money_date_hour': hour,
    }).eq('id', id);
  }

  Future<void> resumeHousehold({
    required String householdId,
    required String partnerId,
  }) async {
    await _client.from('households').update({
      'status': 'active',
      'resumed_at': DateTime.now().toIso8601String(),
    }).eq('id', householdId);

    await _client.from('household_events').insert({
      'household_id': householdId,
      'event_type': 'resumed',
      'initiated_by': partnerId,
    });

    await _client
        .from('goals')
        .update({'status': 'active'})
        .eq('household_id', householdId)
        .eq('status', 'paused');
  }
}
