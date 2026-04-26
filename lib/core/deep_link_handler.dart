import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeepLinkHandler {
  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSub;
  static StreamSubscription<AuthState>? _authSub;
  static String? _pendingJoinCode;

  static void initialize(GoRouter router) {
    // Cold-start link (app launched from deep link)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(uri, router);
    });

    // Link while app is already running
    _linkSub = _appLinks.uriLinkStream.listen((uri) => _handle(uri, router));

    // When auth resolves, flush any pending join code
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn && _pendingJoinCode != null) {
        final code = _pendingJoinCode!;
        _pendingJoinCode = null;
        Future.delayed(const Duration(milliseconds: 500), () {
          router.go('/join?code=$code');
        });
      }
    });
  }

  static void dispose() {
    _linkSub?.cancel();
    _authSub?.cancel();
  }

  static void _handle(Uri uri, GoRouter router) {
    String? code;
    if (uri.host == 'twowallet.app' && uri.path == '/join') {
      code = uri.queryParameters['code'];
    } else if (uri.scheme == 'twowallet' && uri.host == 'invite') {
      code = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }

    if (code == null || code.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Not authenticated yet — store and wait for sign-in
      _pendingJoinCode = code;
      router.go('/onboarding');
    } else {
      // Authenticated — navigate after a brief delay to let the app settle
      Future.delayed(const Duration(milliseconds: 300), () {
        router.go('/join?code=$code');
      });
    }
  }
}
