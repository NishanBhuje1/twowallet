import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_config.dart';
import 'app.dart';
import 'data/services/auth_service.dart';
import 'data/services/revenue_cat_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SupabaseConfig.assertConfigured();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
    ),
  );

  // Handle OAuth redirect deep links — resolves session and fixes display name.
  // Only forward OAuth callbacks (com.twowallet.twowallet://login-callback);
  // invite deep links (twowallet://invite/...) are handled by DeepLinkService.
  final authService = AuthService();
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    if (uri.scheme == 'com.twowallet.twowallet') {
      authService.handleOAuthCallback(uri);
    }
  });

  await NotificationService.init();
  await AnalyticsService.init();

  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    try {
      await RevenueCatService.init(user.id);
    } catch (e) {
      debugPrint(
          'RevenueCat init failed: $e — continuing without subscriptions');
    }
  }

  runApp(const ProviderScope(child: TwoWalletApp()));
}
