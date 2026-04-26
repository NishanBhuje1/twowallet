import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/currency_ext.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/partner.dart';
import '../providers/spending_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import 'transaction_detail_sheet.dart';

class SpendingScreen extends ConsumerWidget {
  const SpendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Spending',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          _BucketFilter(),
          _CategorySummary(),
          _PrivatePocketSummary(),
          Expanded(child: _TransactionList()),
        ],
      ),
    );
  }
}

// ── Bucket filter tabs ────────────────────────────────────────────────────────

class _BucketFilter extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedBucketProvider);

    final tabs = [
      (null, 'All'),
      ('mine', 'My spending'),
      ('ours', 'Our spending'),
      ('theirs', "Partner's spending"),
    ];

    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
          final (value, label) = tab;
          final isSelected = selected == value;
          final color =
              value == null ? Colors.black87 : AppColors.forBucket(value);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(selectedBucketProvider.notifier).state = value,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
        ),
      ),
    );
  }
}

// ── Category summary ──────────────────────────────────────────────────────────

class _CategorySummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredTransactionsProvider);

    return filteredAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (txs) {
        final expenses = txs.where((t) => !t.isIncome && !t.isPrivate);
        final total = expenses.fold(0.0, (s, t) => s + t.amountAud.abs());

        // Group by category
        final Map<String, double> cats = {};
        for (final t in expenses) {
          final cat = t.category ?? 'Other';
          cats[cat] = (cats[cat] ?? 0) + t.amountAud.abs();
        }

        final sorted = cats.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top = sorted.take(4).toList();

        if (top.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('This month',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(total.toAUD(showCents: false),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              ...top.map((e) {
                final pct = total > 0 ? e.value / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(e.key,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ),
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: const AlwaysStoppedAnimation(AppColors.ours),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 56,
                        child: Text(
                          e.value.toAUD(showCents: false),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ── Transaction list ──────────────────────────────────────────────────────────

class _TransactionList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredTransactionsProvider);
    final partnersAsync = ref.watch(partnersProvider);

    return filteredAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (txs) {
        if (txs.isEmpty) {
          return Center(
            child: Text('No transactions',
                style: TextStyle(color: Colors.grey.shade400)),
          );
        }

        final partners = partnersAsync.value ?? [];

        // Group by date
        final Map<String, List<Transaction>> grouped = {};
        for (final tx in txs) {
          grouped.putIfAbsent(tx.date, () => []).add(tx);
        }
        final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          itemCount: dates.length,
          itemBuilder: (_, i) {
            final date = dates[i];
            final dayTxs = grouped[date]!;
            final parsed = DateTime.parse(date);
            final label = _formatDate(parsed);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500)),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: dayTxs.asMap().entries.map((entry) {
                      final j = entry.key;
                      final tx = entry.value;
                      final isLast = j == dayTxs.length - 1;
                      return _TxRow(tx: tx, partners: partners, isLast: isLast);
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(d.year, d.month, d.day);

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _TxRow extends StatelessWidget {
  final Transaction tx;
  final List<Partner> partners;
  final bool isLast;

  const _TxRow({
    required this.tx,
    required this.partners,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final bucketColor = AppColors.forBucket(tx.bucket);
    final bucketLight = AppColors.lightForBucket(tx.bucket);
    final bucketLabel = switch (tx.bucket) {
      'mine' => 'Me',
      'ours' => 'Us',
      'theirs' => 'P',
      _ => '?',
    };

    final partner = partners.where((p) => p.id == tx.partnerId).firstOrNull;

    return Column(
      children: [
        InkWell(
          onTap: () => showTransactionDetail(context, tx),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bucketLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(bucketLabel,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: bucketColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx.merchantName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          Text(tx.category ?? tx.bucket,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500)),
                          if (partner != null) ...[
                            Text(' · ',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade400)),
                            Text(partner.displayName,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  tx.isIncome
                      ? '+${tx.amountAud.toAUD()}'
                      : '-${tx.amountAud.abs().toAUD()}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tx.isIncome ? AppColors.ours : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              indent: 64,
              endIndent: 16,
              color: Colors.grey.shade100),
      ],
    );
  }
}

// ── Private pocket summary ────────────────────────────────────────────────────

class _PrivatePocketSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Not relevant when viewing the shared 'ours' bucket
    final selectedBucket = ref.watch(selectedBucketProvider);
    if (selectedBucket == 'ours') return const SizedBox.shrink();

    final transactionsAsync = ref.watch(spendingTransactionsProvider);
    final partnersAsync = ref.watch(partnersProvider);

    return transactionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (transactions) {
        final partners = partnersAsync.value ?? [];
        final userId = ref.watch(authUserProvider).value?.id;
        final me = partners.where((p) => p.userId == userId).firstOrNull;
        if (me == null) return const SizedBox.shrink();

        final myPrivateSpent = transactions
            .where((t) => t.isPrivate && t.partnerId == me.id)
            .fold(0.0, (s, t) => s + t.amountAud.abs());

        if (myPrivateSpent == 0) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          child: Row(
            children: [
              const Icon(Icons.lock_outline,
                  size: 16, color: Color(0xFF1D9E75)),
              const SizedBox(width: 8),
              Text('Private pocket',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                myPrivateSpent.toAUD(showCents: false),
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              const SizedBox(width: 4),
              Text('this month',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        );
      },
    );
  }
}
