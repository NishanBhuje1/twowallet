import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/repo_providers.dart';
import '../../home/providers/home_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class MonthlyTotal {
  final String month;
  final double total;
  const MonthlyTotal({required this.month, required this.total});
}

class BucketBreakdown {
  final double mine;
  final double ours;
  final double theirs;
  final double total;
  const BucketBreakdown({
    required this.mine,
    required this.ours,
    required this.theirs,
    required this.total,
  });
}

class CategoryTotal {
  final String category;
  final double amount;
  final double percentage;
  const CategoryTotal({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Fetches the last 6 months of spending in a **single** Supabase query and
/// groups the results in memory. Previously this made 6 sequential round-trips.
final monthlyTotalsProvider = FutureProvider<List<MonthlyTotal>>((ref) async {
  const labels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final now = DateTime.now();

  // One query covering the 6-month window.
  final rangeStart = DateTime(now.year, now.month - 5, 1);
  final rangeEnd   = DateTime(now.year, now.month + 1, 1);
  final allTxs = await ref
      .read(transactionRepoProvider)
      .fetchDateRange(rangeStart, rangeEnd);

  // Group into YYYY-MM buckets in a single O(n) pass.
  final Map<String, double> totals = {};
  for (final t in allTxs) {
    if (t.isIncome || t.isPrivate) continue;
    final key = t.date.substring(0, 7); // 'YYYY-MM'
    totals[key] = (totals[key] ?? 0) + t.amountAud.abs();
  }

  final results = <MonthlyTotal>[];
  for (int i = 5; i >= 0; i--) {
    int m = now.month - i;
    int y = now.year;
    if (m <= 0) { m += 12; y -= 1; }
    final key = '$y-${m.toString().padLeft(2, '0')}';
    results.add(MonthlyTotal(month: labels[m - 1], total: totals[key] ?? 0.0));
  }
  return results;
});

final bucketBreakdownProvider = FutureProvider<BucketBreakdown>((ref) async {
  final txs = await ref.watch(allTransactionsThisMonthProvider.future);
  final expenses = txs.where((t) => !t.isIncome && !t.isPrivate);
  double mine = 0, ours = 0, theirs = 0;
  for (final t in expenses) {
    if (t.bucket == Bucket.mine.value)        mine  += t.amountAud.abs();
    else if (t.bucket == Bucket.ours.value)   ours  += t.amountAud.abs();
    else if (t.bucket == Bucket.theirs.value) theirs += t.amountAud.abs();
  }
  return BucketBreakdown(mine: mine, ours: ours, theirs: theirs, total: mine + ours + theirs);
});

final topCategoriesProvider = FutureProvider<List<CategoryTotal>>((ref) async {
  final txs = await ref.watch(allTransactionsThisMonthProvider.future);
  final expenses = txs.where((t) => !t.isIncome && !t.isPrivate);
  final Map<String, double> cats = {};
  for (final t in expenses) {
    final cat = t.category ?? 'Other';
    cats[cat] = (cats[cat] ?? 0) + t.amountAud.abs();
  }
  final total = cats.values.fold(0.0, (s, v) => s + v);
  final sorted = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).map((e) => CategoryTotal(
    category: e.key,
    amount: e.value,
    percentage: total > 0 ? e.value / total : 0,
  )).toList();
});

final lastMonthBucketBreakdownProvider = FutureProvider<BucketBreakdown>((ref) async {
  final now = DateTime.now();
  final m = now.month == 1 ? 12 : now.month - 1;
  final y = now.month == 1 ? now.year - 1 : now.year;
  final txs = await ref.read(transactionRepoProvider).fetchForMonth(y, m);
  final expenses = txs.where((t) => !t.isIncome && !t.isPrivate);
  double mine = 0, ours = 0, theirs = 0;
  for (final t in expenses) {
    if (t.bucket == Bucket.mine.value)        mine  += t.amountAud.abs();
    else if (t.bucket == Bucket.ours.value)   ours  += t.amountAud.abs();
    else if (t.bucket == Bucket.theirs.value) theirs += t.amountAud.abs();
  }
  return BucketBreakdown(mine: mine, ours: ours, theirs: theirs, total: mine + ours + theirs);
});
