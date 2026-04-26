import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/currency_ext.dart';
import '../providers/money_date_provider.dart';
import '../../../data/services/claude_service.dart';
import '../../../data/services/analytics_service.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/subscription_provider.dart';

String _isoWeekKey(DateTime date) {
  final thursday = date.subtract(Duration(days: date.weekday - 4));
  final weekNumber =
      ((thursday.difference(DateTime(thursday.year)).inDays) / 7).ceil();
  return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
}

class MoneyDateScreen extends ConsumerStatefulWidget {
  const MoneyDateScreen({super.key});

  @override
  ConsumerState<MoneyDateScreen> createState() => _MoneyDateScreenState();
}

class _MoneyDateScreenState extends ConsumerState<MoneyDateScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.moneyDateOpened();
  }

  @override
  Widget build(BuildContext context) {
    final weekKey = _isoWeekKey(DateTime.now());
    final insightsAsync = ref.watch(moneyDateInsightsProvider(weekKey));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Money Date',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
      ),
      body: insightsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating your talking points...'),
            ],
          ),
        ),
        error: (e, _) => e is HouseholdNotReadyException
            ? _WaitingForPartner()
            : _InsightsError(onRetry: () => ref.invalidate(moneyDateInsightsProvider(weekKey))),
        data: (insights) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WeekInNumbers(insights: insights),
            const SizedBox(height: 16),
            _TalkingPoints(insights: insights),
            const SizedBox(height: 16),
            _DecisionPrompt(insights: insights),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Error states ─────────────────────────────────────────────────────────────

/// Shown when the household has fewer than 2 partners.
class _WaitingForPartner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(partnersProvider);
    final householdId = partnersAsync.value?.firstOrNull?.householdId ?? '';
    final inviteLink = 'https://twowallet.app/join?code=$householdId';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFE1F5EE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_outlined,
                  size: 40, color: Color(0xFF1D9E75)),
            ),
            const SizedBox(height: 24),
            Text(
              'Waiting for your partner',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your partner hasn\'t joined yet. Send them an invite to unlock your weekly Money Date and AI-powered insights.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: inviteLink));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invite link copied!'),
                      backgroundColor: Color(0xFF1D9E75),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy invite link'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final box = context.findRenderObject() as RenderBox?;
                  final sharePositionOrigin = box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null;
                  await Share.share(
                    'Join my TwoWallet household! $inviteLink',
                    subject: 'Join me on TwoWallet',
                    sharePositionOrigin: sharePositionOrigin,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not share: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share invite'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: const BorderSide(color: Color(0xFF1D9E75)),
                foregroundColor: const Color(0xFF1D9E75),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown for genuine errors (network failure, Claude API error, etc.).
class _InsightsError extends StatelessWidget {
  final VoidCallback onRetry;
  const _InsightsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load your insights',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1D9E75),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Week in numbers ───────────────────────────────────────────────────────────

class _WeekInNumbers extends StatelessWidget {
  final MoneyDateInsights insights;
  const _WeekInNumbers({required this.insights});

  @override
  Widget build(BuildContext context) {
    final total = (insights.weekInNumbers['total_spent'] as num).toDouble();
    final ours = (insights.weekInNumbers['ours_spent'] as num).toDouble();
    final count = insights.weekInNumbers['transaction_count'] as int;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This week',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatBox(
                    label: 'Total spent',
                    value: total.toAUD(showCents: false),
                    color: AppColors.mine),
                const SizedBox(width: 8),
                _StatBox(
                    label: 'Shared',
                    value: ours.toAUD(showCents: false),
                    color: AppColors.ours),
                const SizedBox(width: 8),
                _StatBox(
                    label: 'Transactions',
                    value: '$count',
                    color: AppColors.theirs),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// ── Talking points ────────────────────────────────────────────────────────────

class _TalkingPoints extends ConsumerStatefulWidget {
  final MoneyDateInsights insights;
  const _TalkingPoints({required this.insights});

  @override
  ConsumerState<_TalkingPoints> createState() => _TalkingPointsState();
}

class _TalkingPointsState extends ConsumerState<_TalkingPoints> {
  final Set<int> _checked = {};

  @override
  Widget build(BuildContext context) {
    final isFreeAsync = ref.watch(isFreeProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.oursLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.chat_bubble_outline,
                      size: 16, color: AppColors.ours),
                ),
                const SizedBox(width: 8),
                const Text('Talk about this',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            isFreeAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => _buildTalkingPointsList(context, false),
              data: (isFree) => _buildTalkingPointsList(context, isFree),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTalkingPointsList(BuildContext context, bool isFree) {
    final points = widget.insights.talkingPoints;
    final displayCount = isFree ? 1 : points.length;

    return Column(
      children: [
        ...points.asMap().entries.map((e) {
          final i = e.key;
          final point = e.value;
          final checked = _checked.contains(i);
          final isLocked = isFree && i >= 1;

          if (isLocked) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LockedCard(
                onTap: () => context.push('/paywall'),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() {
                if (checked) {
                  _checked.remove(i);
                } else {
                  _checked.add(i);
                }
              }),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: checked ? AppColors.ours : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: checked ? AppColors.ours : Colors.grey.shade300,
                      ),
                    ),
                    child: checked
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        fontSize: 14,
                        color: checked ? Colors.grey.shade400 : Colors.black87,
                        decoration: checked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _LockedCard extends StatelessWidget {
  final VoidCallback onTap;
  const _LockedCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F5EE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ours),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: AppColors.ours, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upgrade to Together to unlock',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 0),
            ),
            child: Text('Upgrade', style: TextStyle(color: AppColors.ours)),
          ),
        ],
      ),
    );
  }
}

// ── Decision prompt ───────────────────────────────────────────────────────────

class _DecisionPrompt extends StatefulWidget {
  final MoneyDateInsights insights;
  const _DecisionPrompt({required this.insights});

  @override
  State<_DecisionPrompt> createState() => _DecisionPromptState();
}

class _DecisionPromptState extends State<_DecisionPrompt> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.mine.withValues(alpha: 0.3)),
      ),
      color: AppColors.mineLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: AppColors.mine, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This week\'s action',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mineDark)),
                  const SizedBox(height: 4),
                  Text(widget.insights.decisionPrompt,
                      style:
                          TextStyle(fontSize: 14, color: AppColors.mineDark)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Icon(Icons.close, size: 18, color: AppColors.mine),
            ),
          ],
        ),
      ),
    );
  }
}
