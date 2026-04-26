import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/currency_ext.dart';
import '../../../core/utils/fair_split_calc.dart';
import '../../../data/models/transaction.dart';
import '../../../data/models/settlement.dart';
import '../../../data/models/partner.dart';
import '../providers/fair_split_provider.dart';
import '../providers/income_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../data/repositories/household_repository.dart';
import '../../../data/services/analytics_service.dart';

class FairSplitScreen extends ConsumerStatefulWidget {
  const FairSplitScreen({super.key});

  @override
  ConsumerState<FairSplitScreen> createState() => _FairSplitScreenState();
}

class _FairSplitScreenState extends ConsumerState<FairSplitScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.fairSplitViewed();
  }

  @override
  Widget build(BuildContext context) {
    final resultAsync = ref.watch(fairSplitResultProvider);
    final partnersAsync = ref.watch(partnersProvider);
    final historyAsync = ref.watch(settlementHistoryProvider);
    final transactionsAsync = ref.watch(oursTransactionsProvider);
    final incomesAsync = ref.watch(householdIncomesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Fair Split',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              _currentMonth(),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
      body: partnersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (partners) {
          if (partners.length < 2) {
            return const Center(child: Text('Waiting for your partner to join'));
          }

          final partnerA = partners.firstWhere((p) => p.role == 'partner_a');
          final partnerB = partners.firstWhere((p) => p.role == 'partner_b');

          final incomes = incomesAsync.value ?? [];
          final validIncomes =
              incomes.where((i) => i.monthlyIncome > 0).toList();
          final totalIncome =
              validIncomes.fold<double>(0, (s, i) => s + i.monthlyIncome);
          final bothHaveIncome = validIncomes.length >= 2;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // ── Info banner ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Income is auto-calculated from your income transactions over the last 3 months. Add income via the + button in the Spending tab.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Income cards ──────────────────────────────────────────
              if (incomesAsync.isLoading)
                const SizedBox(
                  height: 88,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (incomes.length >= 2)
                Row(
                  children: [
                    Expanded(
                      child: _PartnerIncomeCard(
                        name: incomes[0].displayName,
                        amount: incomes[0].monthlyIncome,
                        sharePercent: totalIncome > 0
                            ? incomes[0].monthlyIncome / totalIncome * 100
                            : 50,
                        source: incomes[0].source,
                        monthsOfData: incomes[0].monthsOfData,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PartnerIncomeCard(
                        name: incomes[1].displayName,
                        amount: incomes[1].monthlyIncome,
                        sharePercent: totalIncome > 0
                            ? incomes[1].monthlyIncome / totalIncome * 100
                            : 50,
                        source: incomes[1].source,
                        monthsOfData: incomes[1].monthsOfData,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // ── Fair split calculation or prompt ──────────────────────
              if (!incomesAsync.isLoading && bothHaveIncome) ...[
                resultAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (result) {
                    if (result == null) return const SizedBox.shrink();
                    final fromPartner = result.fromPartnerId == partnerA.id
                        ? partnerA
                        : partnerB;
                    final toPartner = result.fromPartnerId == partnerA.id
                        ? partnerB
                        : partnerA;
                    return Column(
                      children: [
                        _SettlementHero(
                          result: result,
                          fromPartner: fromPartner,
                          toPartner: toPartner,
                          partnerA: partnerA,
                          partnerB: partnerB,
                        ),
                        const SizedBox(height: 16),
                        _SplitRatioCard(partnerA: partnerA, partnerB: partnerB),
                        const SizedBox(height: 16),
                        _ContributionsCard(
                          result: result,
                          partnerA: partnerA,
                          partnerB: partnerB,
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ] else if (!incomesAsync.isLoading) ...[
                _IncomeSetupPrompt(
                  incomes: incomes,
                  onSetManual: () => _showIncomeSetupSheet(context, ref),
                ),
                const SizedBox(height: 16),
              ],

              // ── Shared expenses (always shown) ────────────────────────
              transactionsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (txs) => txs.isEmpty
                    ? const SizedBox.shrink()
                    : _SharedExpensesCard(
                        transactions: txs,
                        partnerA: partnerA,
                        partnerB: partnerB,
                      ),
              ),
              const SizedBox(height: 16),

              // ── Settlement history (always shown) ─────────────────────
              historyAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (history) => _HistoryCard(history: history),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  void _showIncomeSetupSheet(BuildContext context, WidgetRef ref) {
    final partners = ref.read(partnersProvider).value ?? [];
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final me = partners.where((p) => p.userId == userId).firstOrNull;
    if (me == null) return;

    final incomeController = TextEditingController(
      text: me.monthlyIncomeNetAud != null
          ? me.monthlyIncomeNetAud!.toStringAsFixed(0)
          : '',
    );
    bool visibleToPartner = me.incomeVisibleToPartner;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('My monthly income',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Monthly take-home pay after tax',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.grey.shade500)),
              const SizedBox(height: 20),
              TextFormField(
                controller: incomeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'My monthly income',
                  prefixText: '\$ ',
                  hintText: '5000',
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Visible to partner',
                    style: GoogleFonts.inter(fontSize: 14)),
                subtitle: Text(
                  'Your partner can see this income for fair split',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
                value: visibleToPartner,
                activeColor: const Color(0xFF1D9E75),
                onChanged: (v) => setSheetState(() => visibleToPartner = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final income = double.tryParse(incomeController.text);
                  if (income == null || income <= 0) return;

                  final client = Supabase.instance.client;

                  await client.from('partners').update({
                    'monthly_income_net_aud': income,
                    'income_visible_to_partner': visibleToPartner,
                  }).eq('id', me.id);

                  // Update household ratio if both incomes are now visible
                  final updatedPartners =
                      await client.from('partners').select().eq(
                            'household_id', me.householdId);
                  final all = updatedPartners
                      .map((j) => Partner.fromJson(j as Map<String, dynamic>))
                      .toList();
                  final other =
                      all.where((p) => p.userId != userId).firstOrNull;

                  if (other != null &&
                      other.monthlyIncomeNetAud != null &&
                      other.incomeVisibleToPartner &&
                      visibleToPartner) {
                    final total = income + other.monthlyIncomeNetAud!;
                    final myRatio = income / total;
                    await client.from('households').update({
                      'split_ratio_a':
                          me.role == 'partner_a' ? myRatio : 1 - myRatio,
                      'split_method': 'income_ratio',
                    }).eq('id', me.householdId);
                    ref.invalidate(fairSplitResultProvider);
                    ref.invalidate(householdProvider);
                  }

                  ref.invalidate(partnersProvider);
                  ref.invalidate(householdIncomesProvider);

                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1D9E75),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Save',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _currentMonth() {
    final now = DateTime.now();
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
    return '${months[now.month - 1]} ${now.year}';
  }
}

// ── Partner income card ───────────────────────────────────────────────────────

class _PartnerIncomeCard extends StatelessWidget {
  final String name;
  final double amount;
  final double sharePercent;
  final String source;
  final int monthsOfData;

  const _PartnerIncomeCard({
    required this.name,
    required this.amount,
    required this.sharePercent,
    required this.source,
    required this.monthsOfData,
  });

  @override
  Widget build(BuildContext context) {
    final hasIncome = amount > 0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasIncome ? '\$${amount.toStringAsFixed(0)}/mo' : 'Not set',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: hasIncome ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
            if (hasIncome) ...[
              Text(
                '${sharePercent.toStringAsFixed(0)}% share',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                source == 'calculated'
                    ? 'Avg from $monthsOfData ${monthsOfData == 1 ? "month" : "months"}'
                    : 'Manual entry',
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Income setup prompt ───────────────────────────────────────────────────────

class _IncomeSetupPrompt extends StatelessWidget {
  final List<PartnerIncome> incomes;
  final VoidCallback onSetManual;

  const _IncomeSetupPrompt({
    required this.incomes,
    required this.onSetManual,
  });

  @override
  Widget build(BuildContext context) {
    final missingNames = incomes
        .where((i) => i.monthlyIncome <= 0)
        .map((i) => i.displayName)
        .toList();

    final message = missingNames.isEmpty
        ? 'Add income transactions to unlock fair split'
        : '${missingNames.join(" & ")} ${missingNames.length == 1 ? "hasn't" : "haven't"} logged income yet';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E8),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFBA7517).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFBA7517), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFBA7517),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onSetManual,
                  child: Text(
                    'Or set manual income →',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFBA7517),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settlement hero card ──────────────────────────────────────────────────────

class _SettlementHero extends ConsumerWidget {
  final FairSplitResult result;
  final Partner fromPartner;
  final Partner toPartner;
  final Partner partnerA;
  final Partner partnerB;

  const _SettlementHero({
    required this.result,
    required this.fromPartner,
    required this.toPartner,
    required this.partnerA,
    required this.partnerB,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              result.isEven
                  ? 'You\'re square'
                  : '${fromPartner.displayName} owes ${toPartner.displayName}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              result.isEven ? '🎉' : result.settlementAmount.toAUD(),
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w600,
                color: result.isEven ? AppColors.ours : AppColors.mine,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${result.totalOurs.toAUD(showCents: false)} total shared expenses',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            if (!result.isEven) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _showSettleSheet(context, ref),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mine,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Settle up'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSettleSheet(BuildContext context, WidgetRef ref) {
    AnalyticsService.settleUpTapped();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettleSheet(
        amount: result.settlementAmount,
        fromPartner: fromPartner,
        toPartner: toPartner,
      ),
    );
  }
}

// ── Settle up bottom sheet ────────────────────────────────────────────────────

class _SettleSheet extends StatelessWidget {
  final double amount;
  final Partner fromPartner;
  final Partner toPartner;

  const _SettleSheet({
    required this.amount,
    required this.fromPartner,
    required this.toPartner,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settle ${amount.toAUD()} with ${toPartner.displayName}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _SettleOption(
            icon: Icons.attach_money,
            title: 'PayID',
            subtitle: 'Instant AU bank transfer',
            onTap: () => Navigator.pop(context),
          ),
          _SettleOption(
            icon: Icons.account_balance,
            title: 'BSB + account number',
            subtitle: 'Copy details for manual transfer',
            onTap: () => Navigator.pop(context),
          ),
          _SettleOption(
            icon: Icons.copy,
            title: 'Copy amount',
            subtitle: amount.toAUD(),
            onTap: () {
              Clipboard.setData(ClipboardData(text: amount.toAUD()));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Amount copied')),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SettleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

// ── Split ratio card ──────────────────────────────────────────────────────────

class _SplitRatioCard extends ConsumerWidget {
  final Partner partnerA;
  final Partner partnerB;

  const _SplitRatioCard({required this.partnerA, required this.partnerB});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdAsync = ref.watch(householdProvider);

    return householdAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (household) {
        if (household == null) return const SizedBox.shrink();
        final ratioA = (household.splitRatioA * 100).round();
        final ratioB = 100 - ratioA;

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
                Text('Split ratio',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Flexible(
                        flex: ratioA,
                        child: Container(height: 8, color: AppColors.mine),
                      ),
                      Flexible(
                        flex: ratioB,
                        child: Container(height: 8, color: AppColors.theirs),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${partnerA.displayName} $ratioA%',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mineDark,
                            fontWeight: FontWeight.w500)),
                    Text('${partnerB.displayName} $ratioB%',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.theirsDark,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  household.splitMethod == 'income_ratio'
                      ? 'Based on income'
                      : 'Custom ratio',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Contributions card ────────────────────────────────────────────────────────

class _ContributionsCard extends StatelessWidget {
  final FairSplitResult result;
  final Partner partnerA;
  final Partner partnerB;

  const _ContributionsCard({
    required this.result,
    required this.partnerA,
    required this.partnerB,
  });

  @override
  Widget build(BuildContext context) {
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
            const Text('This month\'s contributions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            _ContributionRow(
              partner: partnerA,
              paid: result.partnerAPaid,
              share: result.partnerAShare,
              avatarColor: AppColors.mineLight,
              avatarTextColor: AppColors.mineDark,
            ),
            const Divider(height: 24),
            _ContributionRow(
              partner: partnerB,
              paid: result.partnerBPaid,
              share: result.partnerBShare,
              avatarColor: AppColors.theirsLight,
              avatarTextColor: AppColors.theirsDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  final Partner partner;
  final double paid;
  final double share;
  final Color avatarColor;
  final Color avatarTextColor;

  const _ContributionRow({
    required this.partner,
    required this.paid,
    required this.share,
    required this.avatarColor,
    required this.avatarTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final diff = paid - share;
    final overpaid = diff >= 0;

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: avatarColor,
          child: Text(
            partner.displayName.substring(0, 2).toUpperCase(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: avatarTextColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(partner.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('Fair share: ${share.toAUD()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(paid.toAUD(),
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              '${overpaid ? '+' : ''}${diff.toAUD()} ${overpaid ? 'overpaid' : 'underpaid'}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: overpaid ? AppColors.ours : AppColors.theirs,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared expenses card ──────────────────────────────────────────────────────

class _SharedExpensesCard extends StatelessWidget {
  final List<Transaction> transactions;
  final Partner partnerA;
  final Partner partnerB;

  const _SharedExpensesCard({
    required this.transactions,
    required this.partnerA,
    required this.partnerB,
  });

  @override
  Widget build(BuildContext context) {
    final expenses = transactions.where((t) => !t.isIncome).toList();

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
            const Text('Shared expenses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...expenses.map((tx) {
              final paidBy = tx.partnerId == partnerA.id
                  ? partnerA.displayName
                  : partnerB.displayName;
              return _ExpenseRow(tx: tx, paidBy: paidBy);
            }),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total shared',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  expenses.fold(0.0, (s, t) => s + t.amountAud.abs()).toAUD(),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final Transaction tx;
  final String paidBy;

  const _ExpenseRow({required this.tx, required this.paidBy});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.ours,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.merchantName, style: const TextStyle(fontSize: 14)),
                Text('Paid by $paidBy',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Text(tx.amountAud.abs().toAUD(),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Settlement history card ───────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final List<Settlement> history;
  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

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
            const Text('Settlement history',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            ...history.map((s) => _HistoryRow(settlement: s)),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Settlement settlement;
  const _HistoryRow({required this.settlement});

  @override
  Widget build(BuildContext context) {
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
    final parsed = DateTime.parse(settlement.month);
    final label = '${months[parsed.month - 1]} ${parsed.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Row(
            children: [
              Text(settlement.amountAud.toAUD(),
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: settlement.settled
                      ? AppColors.oursLight
                      : AppColors.theirsLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  settlement.settled ? 'Settled' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    color: settlement.settled
                        ? AppColors.oursDark
                        : AppColors.theirsDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
