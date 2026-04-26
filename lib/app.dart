import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/deep_link_handler.dart';
import 'shared/providers/auth_provider.dart';
import 'features/onboarding/screens/signup_screen.dart';
import 'features/onboarding/screens/invite_screen.dart';
import 'features/onboarding/screens/join_screen.dart';
import 'features/fair_split/screens/fair_split_screen.dart';
import 'features/onboarding/screens/signin_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/goals/screens/goals_screen.dart';
import 'features/spending/screens/spending_screen.dart';
import 'features/money_date/screens/money_date_screen.dart';
import 'features/spending/screens/add_transaction_screen.dart';
import 'features/settings/screens/relationship_status_screen.dart';
import 'features/settings/screens/notification_settings_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/paywall/screens/paywall_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/onboarding_controller.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (context, state) async {
      // Allow /join regardless of auth state — deep-link invite flow
      if (state.matchedLocation == '/join') return null;

      final authState = ref.watch(authUserProvider);
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final hasSeenOnboarding = await OnboardingController.hasSeenOnboarding();

      if (isLoggedIn) {
        // Always go home if logged in — never leave the user stuck on auth screens
        if (state.matchedLocation == '/onboarding' ||
            state.matchedLocation == '/onboarding/signup' ||
            state.matchedLocation == '/signin') {
          return '/home';
        }
        return null;
      }

      // Not logged in
      final isJoinScreen = state.matchedLocation.startsWith('/onboarding/join') ||
          state.matchedLocation == '/join';
      if (!hasSeenOnboarding &&
          state.matchedLocation != '/onboarding' &&
          !isJoinScreen) {
        return '/onboarding';
      }

      if (!state.matchedLocation.startsWith('/onboarding') &&
          state.matchedLocation != '/signin' &&
          state.matchedLocation != '/join') {
        return '/onboarding';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
          path: '/onboarding/signup', builder: (_, __) => const SignUpScreen()),
      GoRoute(path: '/signin', builder: (_, __) => const SignInScreen()),
      GoRoute(
        path: '/onboarding/invite',
        builder: (_, state) => InviteScreen(householdId: state.extra as String),
      ),
      GoRoute(
        path: '/onboarding/join',
        builder: (_, state) => JoinScreen(
          householdId: state.uri.queryParameters['code'],
        ),
      ),
      GoRoute(
        path: '/join',
        builder: (_, state) => JoinScreen(
          householdId: state.uri.queryParameters['code'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/spending', builder: (_, __) => const SpendingScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/fair-split', builder: (_, __) => const FairSplitScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/goals', builder: (_, __) => const GoalsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/money-date', builder: (_, __) => const MoneyDateScreen()),
      GoRoute(
          path: '/add-transaction',
          builder: (_, __) => const AddTransactionScreen()),
      GoRoute(
          path: '/relationship-status',
          builder: (_, __) => const RelationshipStatusScreen()),
      GoRoute(
          path: '/notification-settings',
          builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(path: '/paywall', builder: (_, __) => const PaywallScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});

// Computed once at app startup, not on every navigation rebuild.
// GoogleFonts calls are O(1) after the first call but still allocate objects —
// hoisting them here ensures a single allocation for the lifetime of the app.
final _appTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: const Color(0xFF1D9E75),
  scaffoldBackgroundColor: const Color(0xFFF8F9FA),
  textTheme: GoogleFonts.interTextTheme(),
  appBarTheme: AppBarTheme(
    backgroundColor: const Color(0xFFF8F9FA),
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.plusJakartaSans(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    ),
    iconTheme: const IconThemeData(color: Colors.black87),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: EdgeInsets.zero,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: GoogleFonts.inter(color: Colors.grey.shade600),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: const Color(0xFF1D9E75),
    unselectedItemColor: Colors.grey.shade400,
    elevation: 0,
    type: BottomNavigationBarType.fixed,
  ),
  dividerTheme: DividerThemeData(
    color: Colors.grey.shade100,
    thickness: 1,
  ),
);

class TwoWalletApp extends ConsumerStatefulWidget {
  const TwoWalletApp({super.key});

  @override
  ConsumerState<TwoWalletApp> createState() => _TwoWalletAppState();
}

class _TwoWalletAppState extends ConsumerState<TwoWalletApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) DeepLinkHandler.initialize(ref.read(routerProvider));
    });
  }

  @override
  void dispose() {
    DeepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TwoWallet',
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      theme: _appTheme,
    );
  }
}
