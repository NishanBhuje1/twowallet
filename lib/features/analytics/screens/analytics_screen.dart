import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/currency_ext.dart';
import '../providers/analytics_provider.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyTotalsProvider);
          ref.invalidate(bucketBreakdownProvider);
          ref.invalidate(topCategoriesProvider);
          ref.invalidate(lastMonthBucketBreakdownProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 100,
              floating: true,
              snap: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              scrolledUnderElevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  'Analytics',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _MonthlyTrendCard(),
                  const SizedBox(height: 12),
                  const _DonutCard(),
                  const SizedBox(height: 12),
                  const _TopCategoriesCard(),
                  const SizedBox(height: 12),
                  const _ComparisonCard(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _Shimmer extends StatelessWidget {
  final double height;
  const _Shimmer({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

Widget _emptyState(String msg) => SizedBox(
      height: 80,
      child: Center(
        child: Text(msg, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      ),
    );

Widget _errorState() => const SizedBox(
      height: 60,
      child: Center(child: Text('Could not load data')),
    );

// ── 1. Monthly trend line chart ───────────────────────────────────────────────

class _MonthlyTrendCard extends ConsumerWidget {
  const _MonthlyTrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(monthlyTotalsProvider);

    return _SectionCard(
      title: 'Monthly Spending',
      child: dataAsync.when(
        loading: () => const _Shimmer(height: 180),
        error: (_, __) => _errorState(),
        data: (data) {
          if (data.isEmpty || data.every((d) => d.total == 0)) {
            return _emptyState('No spending data yet');
          }

          final maxY = data.map((d) => d.total).reduce((a, b) => a > b ? a : b);
          final spots = data
              .asMap()
              .entries
              .map((e) => FlSpot(e.key.toDouble(), e.value.total))
              .toList();

          return SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 500,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data[i].month,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        final label = value >= 1000
                            ? '\$${(value / 1000).toStringAsFixed(0)}k'
                            : '\$${value.toInt()}';
                        return Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                minY: 0,
                maxY: maxY * 1.25,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.ours,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.ours,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.ours.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 2. Bucket donut chart ─────────────────────────────────────────────────────

class _DonutCard extends ConsumerWidget {
  const _DonutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(bucketBreakdownProvider);

    return _SectionCard(
      title: 'Spending by Bucket',
      child: dataAsync.when(
        loading: () => const _Shimmer(height: 220),
        error: (_, __) => _errorState(),
        data: (bd) {
          if (bd.total == 0) return _emptyState('No spending this month');

          final sections = [
            if (bd.mine > 0)
              PieChartSectionData(
                color: AppColors.mine,
                value: bd.mine,
                radius: 36,
                title: '',
              ),
            if (bd.ours > 0)
              PieChartSectionData(
                color: AppColors.ours,
                value: bd.ours,
                radius: 36,
                title: '',
              ),
            if (bd.theirs > 0)
              PieChartSectionData(
                color: AppColors.theirs,
                value: bd.theirs,
                radius: 36,
                title: '',
              ),
          ];

          return Column(
            children: [
              SizedBox(
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 55,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                        sections: sections,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          bd.total.toAUD(showCents: false),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'total',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DonutLegend(
                    color: AppColors.mine,
                    label: 'My spending',
                    amount: bd.mine,
                    pct: bd.total > 0 ? bd.mine / bd.total : 0,
                  ),
                  _DonutLegend(
                    color: AppColors.ours,
                    label: 'Our spending',
                    amount: bd.ours,
                    pct: bd.total > 0 ? bd.ours / bd.total : 0,
                  ),
                  _DonutLegend(
                    color: AppColors.theirs,
                    label: "Partner's spending",
                    amount: bd.theirs,
                    pct: bd.total > 0 ? bd.theirs / bd.total : 0,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DonutLegend extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;
  final double pct;

  const _DonutLegend({
    required this.color,
    required this.label,
    required this.amount,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount.toAUD(showCents: false),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        Text(
          '${(pct * 100).round()}%',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

// ── 3. Top categories horizontal bar chart ────────────────────────────────────

class _TopCategoriesCard extends ConsumerWidget {
  const _TopCategoriesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(topCategoriesProvider);

    return _SectionCard(
      title: 'Top Categories',
      child: dataAsync.when(
        loading: () => Column(
          children: List.generate(
            5,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _Shimmer(height: 36),
            ),
          ),
        ),
        error: (_, __) => _errorState(),
        data: (categories) {
          if (categories.isEmpty) return _emptyState('No spending this month');

          return Column(
            children: categories.asMap().entries.map((entry) {
              final i = entry.key;
              final cat = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: i < categories.length - 1 ? 16 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cat.category,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              cat.amount.toAUD(showCents: false),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(cat.percentage * 100).round()}%',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(height: 8, color: Colors.grey.shade100),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: cat.percentage),
                            duration: Duration(milliseconds: 500 + i * 120),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return FractionallySizedBox(
                                widthFactor: value,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.ours,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ── 4. Month-over-month comparison ────────────────────────────────────────────

class _ComparisonCard extends ConsumerWidget {
  const _ComparisonCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thisMonthAsync = ref.watch(bucketBreakdownProvider);
    final lastMonthAsync = ref.watch(lastMonthBucketBreakdownProvider);

    return _SectionCard(
      title: 'vs Last Month',
      child: thisMonthAsync.when(
        loading: () => const _Shimmer(height: 160),
        error: (_, __) => _errorState(),
        data: (thisMonth) => lastMonthAsync.when(
          loading: () => const _Shimmer(height: 160),
          error: (_, __) => _errorState(),
          data: (lastMonth) {
            final pctChange = lastMonth.total > 0
                ? (thisMonth.total - lastMonth.total) / lastMonth.total
                : null;
            final increased = pctChange != null && pctChange > 0;
            final changeColor =
                increased ? Colors.orange.shade600 : AppColors.ours;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This month',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            thisMonth.total.toAUD(showCents: false),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (pctChange != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: changeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              increased
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 14,
                              color: changeColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(pctChange.abs() * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: changeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Last month: ${lastMonth.total.toAUD(showCents: false)}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 16),
                _BucketCompRow(
                  label: 'My spending',
                  color: AppColors.mine,
                  thisMonth: thisMonth.mine,
                  lastMonth: lastMonth.mine,
                ),
                const SizedBox(height: 12),
                _BucketCompRow(
                  label: 'Our spending',
                  color: AppColors.ours,
                  thisMonth: thisMonth.ours,
                  lastMonth: lastMonth.ours,
                ),
                const SizedBox(height: 12),
                _BucketCompRow(
                  label: "Partner's spending",
                  color: AppColors.theirs,
                  thisMonth: thisMonth.theirs,
                  lastMonth: lastMonth.theirs,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BucketCompRow extends StatelessWidget {
  final String label;
  final Color color;
  final double thisMonth;
  final double lastMonth;

  const _BucketCompRow({
    required this.label,
    required this.color,
    required this.thisMonth,
    required this.lastMonth,
  });

  @override
  Widget build(BuildContext context) {
    final diff = thisMonth - lastMonth;
    final increased = diff > 0;
    final arrowColor =
        increased ? Colors.orange.shade600 : AppColors.ours;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Text(
          thisMonth.toAUD(showCents: false),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        if (diff.abs() > 0.01) ...[
          const SizedBox(width: 8),
          Icon(
            increased
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 12,
            color: arrowColor,
          ),
          Text(
            diff.abs().toAUD(showCents: false),
            style: GoogleFonts.inter(fontSize: 11, color: arrowColor),
          ),
        ],
      ],
    );
  }
}
