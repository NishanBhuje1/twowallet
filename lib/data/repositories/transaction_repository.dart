import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction.dart';
import '../../core/extensions/date_ext.dart';

class TransactionRepository {
  final _client = Supabase.instance.client;

  Future<List<Transaction>> fetchRecent({int limit = 5}) async {
    final data = await _client
        .from('transactions')
        .select()
        .eq('is_private', false)
        .order('date', ascending: false)
        .limit(limit);

    return data.map((e) => Transaction.fromJson(e)).toList();
  }

  Future<List<Transaction>> fetchThisMonthAll() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end   = DateTime(now.year, now.month + 1, 1);

    final data = await _client
        .from('transactions')
        .select()
        .gte('date', start.toSupabaseDate())
        .lt('date', end.toSupabaseDate())
        .order('date', ascending: false);

    return data.map((e) => Transaction.fromJson(e)).toList();
  }

  Future<List<Transaction>> fetchForMonth(int year, int month) async {
    final start    = DateTime(year, month, 1);
    final end      = DateTime(year, month + 1, 1); // DateTime handles month overflow

    final data = await _client
        .from('transactions')
        .select()
        .gte('date', start.toSupabaseDate())
        .lt('date', end.toSupabaseDate())
        .order('date', ascending: false);

    return data.map((e) => Transaction.fromJson(e)).toList();
  }

  /// Single query covering [start, end). Used by analytics to replace
  /// 6 sequential monthly queries with one round-trip.
  Future<List<Transaction>> fetchDateRange(DateTime start, DateTime end) async {
    final data = await _client
        .from('transactions')
        .select()
        .gte('date', start.toSupabaseDate())
        .lt('date', end.toSupabaseDate())
        .order('date', ascending: false);

    return data.map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Transaction> addTransaction(Transaction tx) async {
    final data = await _client
        .from('transactions')
        .insert({
          'household_id': tx.householdId,
          'account_id': tx.accountId,
          'partner_id': tx.partnerId,
          'bucket': tx.bucket,
          'amount_aud': tx.amountAud,
          'merchant_name': tx.merchantName,
          'category': tx.category,
          'date': tx.date,
          'is_private': tx.isPrivate,
          'is_income': tx.isIncome,
          'is_recurring': tx.isRecurring,
          'notes': tx.notes,
        })
        .select()
        .single();

    return Transaction.fromJson(data);
  }

  Future<void> updateBucket(String transactionId, String bucket) async {
    await _client
        .from('transactions')
        .update({'bucket': bucket})
        .eq('id', transactionId);
  }

  Future<void> updateCategory(String transactionId, String category) async {
    await _client
        .from('transactions')
        .update({'category': category})
        .eq('id', transactionId);
  }

  Future<void> updateTransaction({
    required String transactionId,
    required double amountAud,
    required String merchantName,
    required String bucket,
    required String category,
    required bool isIncome,
    required bool isPrivate,
    String? notes,
  }) async {
    await _client.from('transactions').update({
      'amount_aud':    amountAud,
      'merchant_name': merchantName,
      'bucket':        bucket,
      'category':      category,
      'is_income':     isIncome,
      'is_private':    isPrivate,
      'notes':         notes,
    }).eq('id', transactionId);
  }

  Future<void> deleteTransaction(String transactionId) async {
    final deleted = await _client
        .from('transactions')
        .delete()
        .eq('id', transactionId)
        .select();

    if (deleted.isEmpty) {
      throw Exception(
          'Delete failed — no rows removed. Check Supabase RLS policies for the transactions table.');
    }
  }
}