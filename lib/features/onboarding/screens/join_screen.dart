import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../features/home/providers/home_provider.dart';
import '../../../features/fair_split/providers/fair_split_provider.dart';
import '../../../features/goals/providers/goals_provider.dart';
import '../../../features/spending/providers/spending_provider.dart';
import '../onboarding_controller.dart';

class JoinScreen extends ConsumerStatefulWidget {
  final String? householdId;
  const JoinScreen({super.key, this.householdId});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _joinHousehold() async {
    if (widget.householdId == null || widget.householdId!.isEmpty) {
      setState(() => _error = 'No invite code provided');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        context.go('/signin?redirectTo=/join?code=${widget.householdId}');
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.rpc(
        'join_household_by_id',
        params: {'p_household_id': widget.householdId},
      );

      await OnboardingController.markOnboardingComplete();
      await OnboardingController.markSetupComplete();

      if (mounted) {
        // Invalidate all household-dependent providers so the home screen
        // reflects the new household membership immediately
        ref.invalidate(partnersProvider);
        ref.invalidate(myPartnerProvider);
        ref.invalidate(householdProvider);
        ref.invalidate(bucketTotalsProvider);
        ref.invalidate(recentTransactionsProvider);
        ref.invalidate(allTransactionsThisMonthProvider);
        ref.invalidate(spendingTransactionsProvider);
        ref.invalidate(goalsProvider);
        ref.invalidate(goalsNotifierProvider);
        ref.invalidate(fairSplitResultProvider);
        ref.invalidate(oursTransactionsProvider);
        ref.invalidate(settlementHistoryProvider);
        ref.invalidate(settlementNotifierProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined household!'),
            backgroundColor: Color(0xFF1D9E75),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('PostgrestException: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: Color(0xFFE1F5EE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 40,
                  color: Color(0xFF1D9E75),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You\'ve been invited!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your partner is waiting for you on TwoWallet. Join their household to start managing money together.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
              const Spacer(flex: 3),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade900, fontSize: 14),
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _joinHousehold,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Join household',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/onboarding'),
                child: Text(
                  'Create my own account instead',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
