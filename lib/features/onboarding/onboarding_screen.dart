import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twowallet/shared/providers/auth_provider.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;
  bool _loading = false;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _complete() async {
    await OnboardingController.markOnboardingComplete();
    await OnboardingController.markSetupComplete();
    if (mounted) context.go('/home');
  }

  Future<void> _goToSignup() async {
    await OnboardingController.markOnboardingComplete();
    if (mounted) context.go('/onboarding/signup');
  }

  Future<void> _goToSignin() async {
    await OnboardingController.markOnboardingComplete();
    if (mounted) context.go('/signin');
  }

  Future<void> _signInWithGoogle() async {
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      await OnboardingController.markOnboardingComplete();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign in failed: $e')),
        );
      }
    }
  }

  Future<void> _signInWithApple() async {
    if (_loading) return;
    try {
      setState(() => _loading = true);
      await ref.read(authServiceProvider).signInWithApple();
      await OnboardingController.markOnboardingComplete();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apple sign in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? const Color(0xFF1D9E75)
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _Page1(),
                  _Page2(),
                  _Page3(),
                ],
              ),
            ),

            // Fixed bottom actions
            _BottomActions(
              currentPage: _currentPage,
              onNext: _nextPage,
              onLogin: _goToSignin,
              onGetStarted: _nextPage,
              onSignup: _goToSignup,
              onStart: _complete,
              onGoogle: _signInWithGoogle,
              onApple: _signInWithApple,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 1 — The Vision ───────────────────────────────────────────────────────

class _Page1 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'Build your future,\ntogether.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SvgPicture.asset(
              'assets/onboarding/vision_couple_planning.svg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Unified tools for couples, simplified.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Page 2 — Deep Feature Value ───────────────────────────────────────────────

class _Page2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Built for\nyour team.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Everything a couple needs to manage money.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          const _FeatureCard(
            title: 'Track together',
            subtitle: 'See every coin. Transactions\ncategorized and understood.',
            svgPath: 'assets/onboarding/feature_track_magnifier.svg',
            color: Color(0xFF378ADD),
          ),
          const SizedBox(height: 14),
          const _FeatureCard(
            title: 'Split fairly',
            subtitle: 'Automatic, fair splits.\nSet percentages or amount.',
            svgPath: 'assets/onboarding/feature_split_scale.svg',
            color: Color(0xFF1D9E75),
          ),
          const SizedBox(height: 14),
          const _FeatureCard(
            title: 'Reach goals',
            subtitle: 'Goal progress, shared. Save for\nyour home, travel, or car.',
            svgPath: 'assets/onboarding/feature_goal_mountain.svg',
            color: Color(0xFFBA7517),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String svgPath;
  final Color color;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.svgPath,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Text content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Large illustration aligned right
            SizedBox(
              width: 110,
              height: 120,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Colored background arc
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Container(
                      width: 110,
                      height: 140,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(60),
                          bottomLeft: Radius.circular(60),
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  // SVG illustration
                  Positioned(
                    right: 8,
                    top: 8,
                    child: SvgPicture.asset(
                      svgPath,
                      width: 95,
                      height: 105,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page 3 — Reduced Friction Gate ───────────────────────────────────────────

class _Page3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'Finalize your\nprofile.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SvgPicture.asset(
              'assets/onboarding/activation_interlocking_profiles.svg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Start building your shared universe.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Fixed Bottom Actions ──────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final int currentPage;
  final VoidCallback onNext;
  final VoidCallback onLogin;
  final VoidCallback onGetStarted;
  final VoidCallback onSignup;
  final VoidCallback onStart;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  const _BottomActions({
    required this.currentPage,
    required this.onNext,
    required this.onLogin,
    required this.onGetStarted,
    required this.onSignup,
    required this.onStart,
    required this.onGoogle,
    required this.onApple,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      color: const Color(0xFFF8F9FA),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (currentPage == 0) ...[
            _PrimaryButton(label: 'Get started', onTap: onGetStarted),
          ] else if (currentPage == 1) ...[
            _PrimaryButton(label: 'Continue', onTap: onNext),
          ] else ...[
            if (!Platform.isIOS) ...[
              _SocialButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                color: const Color(0xFF4285F4),
                onTap: onGoogle,
              ),
              const SizedBox(height: 10),
            ],
            if (Platform.isIOS) ...[
              _SocialButton(
                label: 'Continue with Apple',
                icon: Icons.apple,
                color: Colors.black,
                onTap: onApple,
              ),
              const SizedBox(height: 10),
            ],
            _PrimaryButton(label: 'Start Tracking!', onTap: onLogin),
          ],
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1D9E75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
