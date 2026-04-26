import 'package:supabase_flutter/supabase_flutter.dart';

class SeedDataService {
  static final _client = Supabase.instance.client;

  /// Returns true if this household already has transactions.
  static Future<bool> hasData() async {
    final result = await _client
        .from('transactions')
        .select('id')
        .limit(1);
    return result.isNotEmpty;
  }

  static Future<void> seed() async {
    // ── Resolve household & partners ─────────────────────────────────────────
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final myPartnerRow = await _client
        .from('partners')
        .select('id, household_id, role')
        .eq('user_id', userId)
        .single();

    final householdId = myPartnerRow['household_id'] as String;
    final myPartnerId = myPartnerRow['id'] as String;
    final myRole = myPartnerRow['role'] as String;

    final allPartners = await _client
        .from('partners')
        .select('id, role')
        .eq('household_id', householdId);

    final otherPartner = allPartners.firstWhere(
      (p) => p['id'] != myPartnerId,
      orElse: () => myPartnerRow,
    );
    final otherPartnerId = otherPartner['id'] as String;

    // Partner A = first partner, Partner B = second
    final partnerAId = myRole == 'partner_a' ? myPartnerId : otherPartnerId;
    final partnerBId = myRole == 'partner_b' ? myPartnerId : otherPartnerId;

    // ── Get or create a manual account for each bucket ───────────────────────
    Future<String> accountFor(String bucket, String ownerId) async {
      final existing = await _client
          .from('accounts')
          .select('id')
          .eq('household_id', householdId)
          .eq('bucket', bucket)
          .eq('is_manual', true)
          .limit(1);

      if (existing.isNotEmpty) return existing.first['id'] as String;

      final label = switch (bucket) {
        'mine' => 'My Wallet',
        'ours' => 'Joint Wallet',
        _ => 'Their Wallet',
      };

      final result = await _client
          .from('accounts')
          .insert({
            'household_id': householdId,
            'partner_id': bucket == 'ours' ? null : ownerId,
            'bucket': bucket,
            'institution_name': 'Manual',
            'account_name': label,
            'account_type': 'transaction',
            'balance_aud': 0,
            'is_manual': true,
          })
          .select('id')
          .single();

      return result['id'] as String;
    }

    final oursAccountId = await accountFor('ours', partnerAId);
    final mineAccountId = await accountFor('mine', partnerAId);
    final theirsAccountId = await accountFor('theirs', partnerBId);

    // ── Helper ────────────────────────────────────────────────────────────────
    String date(int daysAgo) {
      final d = DateTime.now().subtract(Duration(days: daysAgo));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    // ── Sample transactions ──────────────────────────────────────────────────
    final rows = [
      // ── Shared (ours) ──
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerAId,
        'bucket': 'ours',
        'amount_aud': 187.40,
        'merchant_name': 'Woolworths',
        'category': 'Groceries',
        'date': date(2),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerBId,
        'bucket': 'ours',
        'amount_aud': 94.60,
        'merchant_name': 'Coles',
        'category': 'Groceries',
        'date': date(5),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerAId,
        'bucket': 'ours',
        'amount_aud': 2450.00,
        'merchant_name': 'Sydney Property Mgmt',
        'category': 'Rent',
        'date': date(1),
        'is_private': false,
        'is_income': false,
        'is_recurring': true,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerAId,
        'bucket': 'ours',
        'amount_aud': 22.99,
        'merchant_name': 'Netflix',
        'category': 'Streaming',
        'date': date(8),
        'is_private': false,
        'is_income': false,
        'is_recurring': true,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerBId,
        'bucket': 'ours',
        'amount_aud': 18.99,
        'merchant_name': 'Spotify',
        'category': 'Subscriptions',
        'date': date(8),
        'is_private': false,
        'is_income': false,
        'is_recurring': true,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerAId,
        'bucket': 'ours',
        'amount_aud': 312.00,
        'merchant_name': 'AGL Energy',
        'category': 'Utilities',
        'date': date(12),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerBId,
        'bucket': 'ours',
        'amount_aud': 68.50,
        'merchant_name': 'Italiano Kitchen',
        'category': 'Dining Out',
        'date': date(9),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerAId,
        'bucket': 'ours',
        'amount_aud': 45.20,
        'merchant_name': 'Bondi Thai',
        'category': 'Dining Out',
        'date': date(16),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerAId,
        'bucket': 'ours',
        'amount_aud': 89.00,
        'merchant_name': 'Bunnings',
        'category': 'Other',
        'date': date(19),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },

      // ── Mine (partner A personal) ──
      {
        'household_id': householdId,
        'account_id': mineAccountId,
        'partner_id': partnerAId,
        'bucket': 'mine',
        'amount_aud': 14.50,
        'merchant_name': 'Campos Coffee',
        'category': 'Dining Out',
        'date': date(1),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': mineAccountId,
        'partner_id': partnerAId,
        'bucket': 'mine',
        'amount_aud': 62.00,
        'merchant_name': 'Shell Petrol',
        'category': 'Transport',
        'date': date(4),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': mineAccountId,
        'partner_id': partnerAId,
        'bucket': 'mine',
        'amount_aud': 120.00,
        'merchant_name': 'Headspace',
        'category': 'Health',
        'date': date(10),
        'is_private': false,
        'is_income': false,
        'is_recurring': true,
      },
      {
        'household_id': householdId,
        'account_id': mineAccountId,
        'partner_id': partnerAId,
        'bucket': 'mine',
        'amount_aud': 5500.00,
        'merchant_name': 'Employer Payroll',
        'category': 'Income',
        'date': date(0),
        'is_private': false,
        'is_income': true,
        'is_recurring': true,
      },

      // ── Theirs (partner B personal) ──
      {
        'household_id': householdId,
        'account_id': theirsAccountId,
        'partner_id': partnerBId,
        'bucket': 'theirs',
        'amount_aud': 34.90,
        'merchant_name': 'Glue Store',
        'category': 'Clothing',
        'date': date(3),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': theirsAccountId,
        'partner_id': partnerBId,
        'bucket': 'theirs',
        'amount_aud': 58.00,
        'merchant_name': 'Opal Card Top-up',
        'category': 'Transport',
        'date': date(6),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': theirsAccountId,
        'partner_id': partnerBId,
        'bucket': 'theirs',
        'amount_aud': 4800.00,
        'merchant_name': 'Employer Payroll',
        'category': 'Income',
        'date': date(0),
        'is_private': false,
        'is_income': true,
        'is_recurring': true,
      },

      // ── Last month data (for analytics trends) ──
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerAId,
        'bucket': 'ours',
        'amount_aud': 210.80,
        'merchant_name': 'Woolworths',
        'category': 'Groceries',
        'date': date(32),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerAId,
        'bucket': 'ours',
        'amount_aud': 2450.00,
        'merchant_name': 'Sydney Property Mgmt',
        'category': 'Rent',
        'date': date(31),
        'is_private': false,
        'is_income': false,
        'is_recurring': true,
      },
      {
        'household_id': householdId,
        'account_id': oursAccountId,
        'partner_id': partnerBId,
        'bucket': 'ours',
        'amount_aud': 78.40,
        'merchant_name': 'Coles',
        'category': 'Groceries',
        'date': date(36),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
      {
        'household_id': householdId,
        'account_id': mineAccountId,
        'partner_id': partnerAId,
        'bucket': 'mine',
        'amount_aud': 55.00,
        'merchant_name': 'Shell Petrol',
        'category': 'Transport',
        'date': date(38),
        'is_private': false,
        'is_income': false,
        'is_recurring': false,
      },
    ];

    await _client.from('transactions').insert(rows);
  }
}
