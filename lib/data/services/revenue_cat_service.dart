import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static const _apiKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static bool _isConfigured = false;

  // Your product IDs — match these exactly in App Store / Play Store
  static const monthlyTogether = 'twowallet_together_monthly';
  static const annualTogether = 'twowallet_together_annual';
  static const monthlyTogetherPlus = 'twowallet_together_plus_monthly';
  static const annualTogetherPlus = 'twowallet_together_plus_annual';

  // Entitlement IDs — set these up in RevenueCat dashboard
  static const entitlementTogether = 'together';
  static const entitlementTogetherPlus = 'together_plus';

  /// Initializes RevenueCat with the provided Supabase User ID.
  static Future<void> init(String? userId) async {
    try {
      if (_apiKey.isEmpty) {
        debugPrint('RevenueCat API key not set — skipping init');
        _isConfigured = false;
        return;
      }

      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);

      await Purchases.configure(
        PurchasesConfiguration(_apiKey)..appUserID = userId,
      );
      _isConfigured = true;
    } catch (e) {
      debugPrint('RevenueCat init error: $e — app will work without subscriptions');
      _isConfigured = false;
    }
  }

  static Future<String> getCurrentTier() async {
    if (!_isConfigured) {
      debugPrint('RevenueCat not configured — returning together tier');
      return 'together'; // Default to together during beta
    }

    try {
      final info = await Purchases.getCustomerInfo();
      if (info.entitlements.active.containsKey(entitlementTogetherPlus)) {
        return 'together_plus';
      }
      if (info.entitlements.active.containsKey(entitlementTogether)) {
        return 'together';
      }
      return 'free';
    } catch (e) {
      debugPrint('RevenueCat tier check failed: $e');
      return 'together'; // Default to together during beta
    }
  }

  static Future<List<Package>> getPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? [];
    } catch (e) {
      debugPrint('Error fetching packages: $e');
      return [];
    }
  }

  static Future<CustomerInfo> purchase(Package package) async {
    return Purchases.purchasePackage(package);
  }

  static Future<CustomerInfo> restorePurchases() async {
    return Purchases.restorePurchases();
  }
}