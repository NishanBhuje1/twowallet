import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/revenue_cat_service.dart';

// Provider that returns current tier: 'free', 'together', 'together_plus'
final subscriptionTierProvider = FutureProvider<String>((ref) async {
  return RevenueCatService.getCurrentTier();
});

// Convenience bool providers
final isTogetherProvider = FutureProvider<bool>((ref) async {
  final tier = await ref.watch(subscriptionTierProvider.future);
  return tier == 'together' || tier == 'together_plus';
});

final isTogetherPlusProvider = FutureProvider<bool>((ref) async {
  final tier = await ref.watch(subscriptionTierProvider.future);
  return tier == 'together_plus';
});

final isFreeProvider = FutureProvider<bool>((ref) async {
  final tier = await ref.watch(subscriptionTierProvider.future);
  return tier == 'free';
});
