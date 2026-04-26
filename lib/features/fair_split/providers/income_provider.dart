import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PartnerIncome {
  final String partnerId;
  final String displayName;
  final String role;
  final double monthlyIncome;
  final String source; // 'calculated' or 'manual'
  final int monthsOfData;

  const PartnerIncome({
    required this.partnerId,
    required this.displayName,
    required this.role,
    required this.monthlyIncome,
    required this.source,
    required this.monthsOfData,
  });

  factory PartnerIncome.fromJson(Map<String, dynamic> json) => PartnerIncome(
        partnerId: json['pid'] as String,
        displayName: json['display_name'] as String,
        role: json['role'] as String,
        monthlyIncome: double.parse(json['monthly_income'].toString()),
        source: json['source'] as String,
        monthsOfData: (json['months_of_data'] as num).toInt(),
      );
}

final householdIncomesProvider = FutureProvider<List<PartnerIncome>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final partner = await Supabase.instance.client
      .from('partners')
      .select('household_id')
      .eq('user_id', user.id)
      .single();

  final householdId = partner['household_id'] as String;

  final response = await Supabase.instance.client
      .rpc('get_household_incomes', params: {'p_household_id': householdId});

  return (response as List)
      .map((e) => PartnerIncome.fromJson(e as Map<String, dynamic>))
      .toList();
});
