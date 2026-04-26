import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/currency_ext.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/partner.dart';
import '../providers/home_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../fair_split/providers/fair_split_provider.dart';
import '../../spending/screens/transaction_detail_sheet.dart';
import '../widgets/getting_started_card.dart';
import '../widgets/invite_partner_card.dart';

// ════════════════════════════════════════════════════════════════════════════
// HomeScreen
// Purpose: Bucket overview — the central financial dashboard for the couple.
// ════════════════════════════════════════════════════════════════════════════

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.ours,
        onRefresh: () async {
          ref.invalidate(bucketTotalsProvider);
          ref.invalidate(recentTransactionsProvider);
          ref.invalidate(fairSplitResultProvider);
          ref.invalidate(householdProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Greeting header ────────────────────────────────────────────
            _GreetingHeader(),

            // ── Content ────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _PausedBanner(),
                  const InvitePartnerCard(),
                  _UpgradeBanner(),
                  _BucketCards(),
                  const SizedBox(height: 24),
                  _QuickActionsRow(),
                  const SizedBox(height: 20),
                  _FairSplitBanner(),
                  const SizedBox(height: 24),
                  _RecentTransactions(),
                  const GettingStartedCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Greeting header ──────────────────────────────────────────────────────────

class _GreetingHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'TwoWallet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              // Profile menu
              PopupMenuButton<String>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.mineLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, size: 18, color: AppColors.mine),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem<String>(
                    value: 'upgrade',
                    child: Row(children: [
                      Icon(Icons.star_outline, size: 18),
                      SizedBox(width: 10),
                      Text('Upgrade to Together'),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(children: [
                      Icon(Icons.settings_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Settings'),
                    ]),
                  ),
                  const PopupMenuItem<String>(
                    value: 'notifications',
                    child: Row(children: [
                      Icon(Icons.notifications_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Notification schedule'),
                    ]),
                  ),
                  const PopupMenuItem<String>(
                    value: 'relationship',
                    child: Row(children: [
                      Icon(Icons.pause_circle_outline, size: 18),
                      SizedBox(width: 10),
                      Text('Relationship status'),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'signout',
                    child: Row(children: [
                      Icon(Icons.logout, size: 18, color: AppColors.destructive),
                      SizedBox(width: 10),
                      Text('Sign out', style: TextStyle(color: AppColors.destructive)),
                    ]),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'upgrade') context.push('/paywall');
                  else if (value == 'settings') context.push('/settings');
                  else if (value == 'notifications') context.push('/notification-settings');
                  else if (value == 'relationship') context.push('/relationship-status');
                  else if (value == 'signout') {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/welcome');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Paused banner ─────────────────────────────────────────────────────────────

class _PausedBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(householdProvider).when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (household) {
        if (household == null || !household.isPaused) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => context.push('/relationship-status'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.pause_circle_outline, color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Household paused — tap to resume',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.warning,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.warning, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Stacked bucket cards ──────────────────────────────────────────────────────

class _BucketCards extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync  = ref.watch(bucketTotalsProvider);
    final partnersAsync = ref.watch(partnersProvider);
    final txAsync      = ref.watch(recentTransactionsProvider);
    final allTxAsync   = ref.watch(allTransactionsThisMonthProvider);

    return totalsAsync.when(
      loading: () => const _BucketCardsShimmer(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (totals) {
        final partners = partnersAsync.value ?? [];
        final userId   = ref.watch(authUserProvider).value?.id;
        final me       = partners.where((p) => p.userId == userId).firstOrNull;
        final transactions = txAsync.value ?? [];
        final allTxs   = allTxAsync.value ?? [];

        final myLastTx = transactions
            .where((t) => t.bucket == 'mine' && t.partnerId == me?.id)
            .firstOrNull;
        final ourLastTx   = transactions.where((t) => t.bucket == 'ours').firstOrNull;
        final theirLastTx = transactions.where((t) => t.bucket == 'theirs').firstOrNull;

        // 7-day daily sparkline for Ours bucket
        final oursSparkline = List<double>.generate(7, (i) {
          final day = DateTime.now().subtract(Duration(days: 6 - i));
          final dayStr =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          return allTxs
              .where((t) => t.bucket == 'ours' && !t.isIncome && t.date == dayStr)
              .fold(0.0, (s, t) => s + t.amountAud.abs());
        });

        final combinedTotal = totals.mine + totals.ours + totals.theirs;

        return Column(
          children: [
            _MineBucketCard(
              label: 'My spending',
              amount: totals.mine,
              total: combinedTotal > 0 ? combinedTotal : 1,
              lastTx: myLastTx,
              onAdd: () => context.push('/add-transaction'),
            ),
            const SizedBox(height: 12),
            _OursBucketCard(
              amount: totals.ours,
              lastTx: ourLastTx,
              sparkline: oursSparkline,
              onAdd: () => context.push('/add-transaction'),
            ),
            const SizedBox(height: 12),
            _PartnerBucketCard(
              label: "Partner's spending",
              amount: totals.theirs,
              lastTx: theirLastTx,
            ),
          ],
        );
      },
    );
  }
}

// ── Flat card shared header ────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final String label;
  final Color dotColor;
  final VoidCallback? onAdd;
  final bool isViewOnly;

  const _CardHeader({
    required this.label,
    required this.dotColor,
    this.onAdd,
    this.isViewOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        if (isViewOnly)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined, size: 12, color: dotColor),
                const SizedBox(width: 2),
                Text('View', style: GoogleFonts.inter(fontSize: 12, color: dotColor)),
              ],
            ),
          )
        else if (onAdd != null)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onAdd!();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 12, color: dotColor),
                  const SizedBox(width: 2),
                  Text('Add', style: GoogleFonts.inter(fontSize: 12, color: dotColor)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Mine bucket card ───────────────────────────────────────────────────────────

class _MineBucketCard extends StatelessWidget {
  final String label;
  final double amount;
  final double total;
  final Transaction? lastTx;
  final VoidCallback onAdd;

  const _MineBucketCard({
    required this.label,
    required this.amount,
    required this.total,
    this.lastTx,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/spending'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F2FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(label: label, dotColor: AppColors.mine, onAdd: onAdd),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: amount),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => Text(
                          v.toAUD(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        'spent this month',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      if (lastTx != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: AppColors.mine, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${lastTx!.merchantName}  ·  ${lastTx!.amountAud.abs().toAUD()}',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: _MiniDonutChart(spent: amount, total: total),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ours bucket card ───────────────────────────────────────────────────────────

class _OursBucketCard extends StatelessWidget {
  final double amount;
  final Transaction? lastTx;
  final List<double> sparkline;
  final VoidCallback onAdd;

  const _OursBucketCard({
    required this.amount,
    this.lastTx,
    required this.sparkline,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/spending'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F7F2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(label: 'Our spending', dotColor: AppColors.ours, onAdd: onAdd),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: amount),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOut,
                        builder: (_, v, __) => Text(
                          v.toAUD(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        'spent this month',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      if (lastTx != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: AppColors.ours, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${lastTx!.merchantName}  ·  ${lastTx!.amountAud.abs().toAUD()}',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: Colors.grey.shade600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: _MiniLineChart(data: sparkline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Partner bucket card ────────────────────────────────────────────────────────

class _PartnerBucketCard extends StatelessWidget {
  final String label;
  final double amount;
  final Transaction? lastTx;

  const _PartnerBucketCard({
    required this.label,
    required this.amount,
    this.lastTx,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/spending'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardHeader(label: label, dotColor: AppColors.theirs, isViewOnly: true),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: amount),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (_, v, __) => Text(
                    v.toAUD(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Text(
                  'spent this month',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
                if (lastTx != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: AppColors.theirs, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${lastTx!.merchantName}  ·  ${lastTx!.amountAud.abs().toAUD()}',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini donut chart ───────────────────────────────────────────────────────────

class _MiniDonutChart extends StatelessWidget {
  final double spent;
  final double total;

  const _MiniDonutChart({required this.spent, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = (spent / total).clamp(0.001, 1.0);
    return PieChart(
      PieChartData(
        sectionsSpace: 0,
        centerSpaceRadius: 18,
        sections: [
          PieChartSectionData(
            value: pct * 100,
            color: AppColors.mine,
            radius: 8,
            showTitle: false,
          ),
          PieChartSectionData(
            value: (1 - pct) * 100,
            color: const Color(0xFFD4E5FA),
            radius: 8,
            showTitle: false,
          ),
        ],
      ),
    );
  }
}

// ── Mini line chart ────────────────────────────────────────────────────────────

class _MiniLineChart extends StatelessWidget {
  final List<double> data;

  const _MiniLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasData = data.any((v) => v > 0);
    if (!hasData) {
      return Center(
        child: Container(
          width: 60,
          height: 2,
          color: AppColors.ours.withValues(alpha: 0.3),
        ),
      );
    }
    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppColors.ours,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.ours.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions row ─────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick actions',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickActionCard(
              icon: Icons.add_circle_outline_rounded,
              label: 'Add expense',
              color: AppColors.ours,
              onTap: () => context.push('/add-transaction'),
            ),
            const SizedBox(width: 12),
            _QuickActionCard(
              icon: Icons.favorite_outline_rounded,
              label: 'Money Date',
              color: AppColors.mine,
              onTap: () => context.push('/money-date'),
            ),
            const SizedBox(width: 12),
            _QuickActionCard(
              icon: Icons.balance_outlined,
              label: 'Fair split',
              color: AppColors.theirs,
              onTap: () => context.go('/fair-split'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Upgrade banner ────────────────────────────────────────────────────────────

class _UpgradeBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(householdProvider).when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (household) {
        if (household == null || household.subscriptionTier != 'free') {
          return const SizedBox.shrink();
        }
        return GestureDetector(
          onTap: () => context.push('/paywall'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.mine, AppColors.ours],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Try Together free for 30 days',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Fair split banner ─────────────────────────────────────────────────────────

class _FairSplitBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultAsync   = ref.watch(fairSplitResultProvider);
    final partnersAsync = ref.watch(partnersProvider);

    return resultAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (result) {
        if (result == null) return const SizedBox.shrink();
        final partners = partnersAsync.value ?? [];
        if (partners.length < 2) return const SizedBox.shrink();

        final partnerA = partners.firstWhere((p) => p.role == 'partner_a');
        final partnerB = partners.firstWhere((p) => p.role == 'partner_b');
        final fromPartner = result.fromPartnerId == partnerA.id ? partnerA : partnerB;
        final toPartner   = result.fromPartnerId == partnerA.id ? partnerB : partnerA;

        return GestureDetector(
          onTap: () => context.go('/fair-split'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.isEven
                            ? "You're square this month"
                            : '${fromPartner.displayName} owes ${toPartner.displayName}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.isEven
                            ? 'No settlement needed'
                            : result.settlementAmount.toAUD(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: result.isEven ? 17 : 26,
                          fontWeight: FontWeight.w700,
                          color: result.isEven ? AppColors.success : AppColors.mine,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: result.isEven ? AppColors.oursLight : AppColors.mineLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: result.isEven ? AppColors.ours : AppColors.mine,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Recent transactions ───────────────────────────────────────────────────────

class _RecentTransactions extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RecentTransactions> createState() => _RecentTransactionsState();
}

class _RecentTransactionsState extends ConsumerState<_RecentTransactions> {
  List<Transaction> _cache = [];
  List<Partner>     _partnerCache = [];

  @override
  Widget build(BuildContext context) {
    final txAsync       = ref.watch(recentTransactionsProvider);
    final partnersAsync = ref.watch(partnersProvider);

    if (txAsync.value      != null) _cache        = txAsync.value!;
    if (partnersAsync.value != null) _partnerCache = partnersAsync.value!;

    final transactions = txAsync.value ?? _cache;
    final partners     = partnersAsync.value ?? _partnerCache;
    final isFirstLoad  = _cache.isEmpty && txAsync.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/spending'),
              child: Text(
                'See all',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ours,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (isFirstLoad)
          const _RecentShimmer()
        else if (transactions.isEmpty)
          const SizedBox.shrink()
        else
          _GroupedTransactions(transactions: transactions, partners: partners),
      ],
    );
  }
}


class _GroupedTransactions extends StatelessWidget {
  final List<Transaction> transactions;
  final List<Partner>     partners;

  const _GroupedTransactions({required this.transactions, required this.partners});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Transaction>> grouped = {};
    for (final tx in transactions) {
      grouped.putIfAbsent(tx.date, () => []).add(tx);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dates.asMap().entries.map((dateEntry) {
        final date    = dateEntry.value;
        final dayTxs  = grouped[date]!;
        final label   = _formatDate(DateTime.parse(date));
        final isLast  = dateEntry.key == dates.length - 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 2),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: dayTxs.asMap().entries.map((entry) {
                  final tx     = entry.value;
                  final isRowLast = entry.key == dayTxs.length - 1;
                  return _TransactionRow(
                    tx: tx,
                    partners: partners,
                    isLast: isRowLast,
                  );
                }).toList(),
              ),
            ),
            if (!isLast) const SizedBox(height: 10),
          ],
        );
      }).toList(),
    );
  }

  String _formatDate(DateTime d) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date      = DateTime(d.year, d.month, d.day);

    if (date == today)     return 'Today';
    if (date == yesterday) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

// ── Transaction row ────────────────────────────────────────────────────────────

class _TransactionRow extends StatefulWidget {
  final Transaction  tx;
  final List<Partner> partners;
  final bool isLast;

  const _TransactionRow({
    required this.tx,
    required this.partners,
    required this.isLast,
  });

  @override
  State<_TransactionRow> createState() => _TransactionRowState();
}

class _TransactionRowState extends State<_TransactionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bucketColor = AppColors.forBucket(widget.tx.bucket);

    return Column(
      children: [
        GestureDetector(
          onTapDown: (_) {
            HapticFeedback.selectionClick();
            setState(() => _pressed = true);
          },
          onTapUp: (_) {
            setState(() => _pressed = false);
            showTransactionDetail(context, widget.tx);
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            color: _pressed ? AppColors.background : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bucketColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      _categoryIcon(widget.tx.category),
                      size: 18,
                      color: bucketColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Merchant + category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tx.merchantName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: bucketColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.tx.category ?? widget.tx.bucket,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount
                Text(
                  widget.tx.isIncome
                      ? '+${widget.tx.amountAud.toAUD()}'
                      : '-${widget.tx.amountAud.abs().toAUD()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.tx.isIncome ? AppColors.success : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!widget.isLast)
          Divider(
            height: 1,
            indent: 68,
            endIndent: 16,
            color: AppColors.separatorOpaque,
          ),
      ],
    );
  }

  IconData _categoryIcon(String? category) => switch (category) {
    'Groceries'     => Icons.shopping_basket_outlined,
    'Dining Out'    => Icons.restaurant_outlined,
    'Rent'          => Icons.home_outlined,
    'Utilities'     => Icons.bolt_outlined,
    'Transport'     => Icons.directions_car_outlined,
    'Clothing'      => Icons.checkroom_outlined,
    'Health'        => Icons.favorite_outline,
    'Entertainment' => Icons.movie_outlined,
    'Streaming'     => Icons.play_circle_outline,
    'Subscriptions' => Icons.subscriptions_outlined,
    'Income'        => Icons.account_balance_outlined,
    _               => Icons.receipt_outlined,
  };
}

// ── Loading shimmer ────────────────────────────────────────────────────────────

class _BucketCardsShimmer extends StatefulWidget {
  const _BucketCardsShimmer();

  @override
  State<_BucketCardsShimmer> createState() => _BucketCardsShimmerState();
}

class _BucketCardsShimmerState extends State<_BucketCardsShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final shimmer = Color.lerp(
          const Color(0xFFEEEEEE),
          const Color(0xFFF8F8F8),
          _anim.value,
        )!;
        return Column(
          children: List.generate(3, (i) => Container(
            margin: EdgeInsets.only(bottom: i < 2 ? 12 : 0),
            height: 130,
            decoration: BoxDecoration(
              color: shimmer,
              borderRadius: BorderRadius.circular(20),
            ),
          )),
        );
      },
    );
  }
}

class _RecentShimmer extends StatefulWidget {
  const _RecentShimmer();

  @override
  State<_RecentShimmer> createState() => _RecentShimmerState();
}

class _RecentShimmerState extends State<_RecentShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final shimmer = Color.lerp(
          const Color(0xFFEEEEEE),
          const Color(0xFFF8F8F8),
          _anim.value,
        )!;
        return Container(
          height: 180,
          decoration: BoxDecoration(
            color: shimmer,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}
