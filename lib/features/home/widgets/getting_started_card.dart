import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/providers/auth_provider.dart';
import '../providers/home_provider.dart';

class GettingStartedCard extends ConsumerStatefulWidget {
  const GettingStartedCard({super.key});

  @override
  ConsumerState<GettingStartedCard> createState() => _GettingStartedCardState();
}

class _GettingStartedCardState extends ConsumerState<GettingStartedCard> {
  bool _dismissed = false;
  bool _minimised = false;

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(
          () => _dismissed = prefs.getBool('getting_started_dismissed') ?? false);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('getting_started_dismissed', true);
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final partnersAsync = ref.watch(partnersProvider);
    final transactionsAsync = ref.watch(recentTransactionsProvider);

    return partnersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (partners) {
        final hasPartner = partners.length >= 2;
        final hasTransaction = (transactionsAsync.value ?? []).isNotEmpty;
        final hasIncome = partners.any((p) =>
            p.monthlyIncomeNetAud != null && p.monthlyIncomeNetAud! > 0);

        final steps = [
          _Step(
            title: 'Invite your partner',
            completed: hasPartner,
            onTap: () {},
          ),
          _Step(
            title: 'Add your first transaction',
            completed: hasTransaction,
            onTap: () => context.push('/add-transaction'),
          ),
          _Step(
            title: 'Set your incomes',
            completed: hasIncome,
            onTap: () => context.push('/fair-split'),
          ),
          _Step(
            title: 'Have your first Money Date',
            completed: false,
            onTap: () => context.push('/money-date'),
          ),
        ];

        final completedCount = steps.where((s) => s.completed).length;

        // All done — dismiss permanently
        if (completedCount == steps.length) {
          _dismiss();
          return const SizedBox.shrink();
        }

        if (_minimised) {
          return GestureDetector(
            onTap: () => setState(() => _minimised = false),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.rocket_launch_outlined,
                      size: 16, color: Color(0xFF1D9E75)),
                  const SizedBox(width: 6),
                  Text(
                    'Getting started ($completedCount/${steps.length})',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF1D9E75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rocket_launch_outlined,
                          color: Color(0xFF1D9E75), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Getting started',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _minimised = true),
                    child: Icon(Icons.keyboard_arrow_up,
                        color: Colors.grey.shade400, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completedCount / steps.length,
                  backgroundColor: Colors.grey.shade100,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFF1D9E75)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$completedCount of ${steps.length} completed',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 16),
              ...steps.map((step) => GestureDetector(
                    onTap: step.completed ? null : step.onTap,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: step.completed
                                  ? const Color(0xFF1D9E75)
                                  : Colors.transparent,
                              border: Border.all(
                                color: step.completed
                                    ? const Color(0xFF1D9E75)
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: step.completed
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: step.completed
                                    ? Colors.grey.shade400
                                    : Colors.black87,
                                decoration: step.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: Colors.grey.shade400,
                              ),
                            ),
                          ),
                          if (!step.completed)
                            Icon(Icons.chevron_right,
                                color: Colors.grey.shade300, size: 18),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _Step {
  final String title;
  final bool completed;
  final VoidCallback onTap;

  const _Step({
    required this.title,
    required this.completed,
    required this.onTap,
  });
}
