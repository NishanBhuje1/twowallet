import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/settlement.dart';

class SettlementRepository {
  final _client = Supabase.instance.client;

  Future<List<Settlement>> fetchHistory({int months = 12}) async {
    final cutoff = DateTime.now().subtract(Duration(days: months * 30));
    final cutoffStr = '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-01';

    final data = await _client
        .from('settlements')
        .select()
        .gte('month', cutoffStr)
        .order('month', ascending: false);

    return data.map((e) => Settlement.fromJson(e)).toList();
  }

  Future<Settlement?> fetchThisMonth() async {
    final now = DateTime.now();
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

    final data = await _client
        .from('settlements')
        .select()
        .eq('month', monthStr)
        .maybeSingle();

    if (data == null) return null;
    return Settlement.fromJson(data);
  }

  Future<void> markSettled(String settlementId) async {
    await _client
        .from('settlements')
        .update({
          'settled': true,
          'settled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', settlementId);
  }

  Future<Settlement> saveSettlement({
    required String householdId,
    required double amountAud,
    required String fromPartnerId,
    required String toPartnerId,
  }) async {
    final now = DateTime.now();
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';

    final data = await _client
        .from('settlements')
        .upsert({
          'household_id': householdId,
          'month': monthStr,
          'amount_aud': amountAud,
          'from_partner_id': fromPartnerId,
          'to_partner_id': toPartnerId,
          'settled': false,
        })
        .select()
        .single();

    return Settlement.fromJson(data);
  }
}