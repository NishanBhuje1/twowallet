import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/services/claude_service.dart';
import '../../../core/extensions/date_ext.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/repo_providers.dart';
import '../../home/providers/home_provider.dart';

/// Thrown when the household only has one partner.
/// The Money Date screen uses this to show the invite UI instead of a
/// generic error message.
class HouseholdNotReadyException implements Exception {
  const HouseholdNotReadyException();
}

final claudeServiceProvider = Provider((_) => ClaudeService());

/// Returns the ISO week key for [date], e.g. "2026-W15".
/// Used as the family key so Claude is called at most once per week.
String _isoWeekKey(DateTime date) {
  // ISO week: week containing the Thursday of that week.
  final thursday = date.subtract(Duration(days: date.weekday - 4));
  final weekNumber =
      ((thursday.difference(DateTime(thursday.year)).inDays) / 7).ceil();
  return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
}

/// Keyed by ISO week string so the Claude response is cached for the full
/// week. Re-entering the Money Date tab re-uses the cached value instead of
/// making a new API call.
final moneyDateInsightsProvider =
    FutureProvider.autoDispose.family<MoneyDateInsights, String>(
        (ref, weekKey) async {
  final now = DateTime.now();
  final weekStart    = now.subtract(Duration(days: now.weekday - 1));
  final weekStartStr = weekStart.toSupabaseDate();

  // Reuse the month's transactions already cached by allTransactionsThisMonthProvider
  // rather than making a redundant fetchThisMonthAll() call.
  final allTxs = await ref.watch(allTransactionsThisMonthProvider.future);
  final weekTxs =
      allTxs.where((t) => t.date.compareTo(weekStartStr) >= 0).toList();

  final household = await ref.read(householdRepoProvider).fetchMyHousehold();
  final partners  = await ref.read(partnersProvider.future);

  if (household == null || partners.length < 2) {
    throw const HouseholdNotReadyException();
  }

  return ref.read(claudeServiceProvider).generateMoneyDateInsights(
        weekTransactions: weekTxs,
        household: household,
        partners: partners,
      );
});
