import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/transaction.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../fair_split/providers/fair_split_provider.dart';
import '../../fair_split/providers/income_provider.dart';
import '../../home/providers/home_provider.dart';
import '../providers/spending_provider.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../../shared/providers/subscription_provider.dart';
import '../../../data/services/analytics_service.dart';

// ════════════════════════════════════════════════════════════════════════════
// AddTransactionScreen
// Purpose: Full-screen sheet for logging a new transaction.
// ════════════════════════════════════════════════════════════════════════════

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  // ── Form state ────────────────────────────────────────────────────────────
  final _amountController   = TextEditingController();
  final _merchantController = TextEditingController();
  final _notesController    = TextEditingController();
  final _merchantFocus      = FocusNode();

  String _bucket       = 'ours';
  String _category     = 'Groceries';
  bool   _isIncome     = false;
  bool   _isPrivate    = false;
  bool   _loading      = false;
  bool   _showSuccess  = false;
  String? _error;

  static const _expenseCategories = [
    'Groceries', 'Dining Out', 'Rent', 'Utilities', 'Transport',
    'Clothing', 'Health', 'Entertainment', 'Streaming', 'Subscriptions',
    'Food Delivery', 'Travel', 'Insurance', 'Other',
  ];

  static const _incomeCategories = [
    'Salary', 'Freelance', 'Rental Income',
    'Investment Return', 'Gift', 'Refund', 'Other Income',
  ];

  double get _amount => double.tryParse(_amountController.text) ?? 0.0;
  bool get _canSubmit => _amount > 0 && !_loading;

  // ── Icons per category ────────────────────────────────────────────────────
  static const _categoryIcons = <String, IconData>{
    'Groceries':        Icons.shopping_basket_outlined,
    'Dining Out':       Icons.restaurant_outlined,
    'Rent':             Icons.home_outlined,
    'Utilities':        Icons.bolt_outlined,
    'Transport':        Icons.directions_car_outlined,
    'Clothing':         Icons.checkroom_outlined,
    'Health':           Icons.favorite_outline,
    'Entertainment':    Icons.movie_outlined,
    'Streaming':        Icons.play_circle_outline,
    'Subscriptions':    Icons.subscriptions_outlined,
    'Food Delivery':    Icons.delivery_dining_outlined,
    'Travel':           Icons.flight_outlined,
    'Insurance':        Icons.security_outlined,
    'Other':            Icons.more_horiz_outlined,
    'Salary':           Icons.account_balance_outlined,
    'Freelance':        Icons.laptop_outlined,
    'Rental Income':    Icons.home_work_outlined,
    'Investment Return':Icons.trending_up_outlined,
    'Gift':             Icons.card_giftcard_outlined,
    'Refund':           Icons.replay_outlined,
    'Other Income':     Icons.attach_money_outlined,
  };

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    _merchantFocus.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_amount <= 0) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (_merchantController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a merchant name');
      _merchantFocus.requestFocus();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    try {
      // Resolve the current user's own partner record.
      final me = await ref.read(myPartnerProvider.future);
      if (me == null) throw Exception('Account setup incomplete — please restart the app.');

      final accountId = await _getOrCreateAccountId(
        householdId: me.householdId,
        partnerId:   me.id,
        bucket:      _bucket,
      );

      final now     = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      await ref.read(transactionRepoProvider).addTransaction(
        Transaction(
          id:           '',
          householdId:  me.householdId,
          accountId:    accountId,
          partnerId:    me.id,
          bucket:       _bucket,
          amountAud:    _amount,
          merchantName: _merchantController.text.trim(),
          category:     _category,
          date:         dateStr,
          isIncome:     _isIncome,
          isPrivate:    _isPrivate,
          notes:        _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
      );

      await AnalyticsService.transactionAdded(_bucket, _category);

      ref.invalidate(spendingTransactionsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(allTransactionsThisMonthProvider);
      ref.invalidate(oursTransactionsProvider);
      ref.invalidate(monthlyTotalsProvider);
      ref.invalidate(lastMonthBucketBreakdownProvider);
      ref.invalidate(fairSplitResultProvider);
      if (_isIncome) ref.invalidate(householdIncomesProvider);

      HapticFeedback.mediumImpact();
      setState(() { _showSuccess = true; _loading = false; });

      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) context.pop();
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<String> _getOrCreateAccountId({
    required String householdId,
    required String partnerId,
    required String bucket,
  }) async {
    final client = Supabase.instance.client;

    final existing = await client
        .from('accounts')
        .select()
        .eq('household_id', householdId)
        .eq('bucket', bucket)
        .eq('is_manual', true)
        .limit(1);

    if (existing.isNotEmpty) return existing.first['id'] as String;

    final label = switch (bucket) {
      'mine'   => 'My Wallet',
      'ours'   => 'Joint Wallet',
      _        => 'Their Wallet',
    };

    final result = await client
        .from('accounts')
        .insert({
          'household_id':    householdId,
          'partner_id':      bucket == 'ours' ? null : partnerId,
          'bucket':          bucket,
          'institution_name':'Manual',
          'account_name':    label,
          'account_type':    'transaction',
          'balance_aud':     0,
          'is_manual':       true,
        })
        .select()
        .single();

    return result['id'] as String;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bucketColor = AppColors.forBucket(_bucket);
    final categories  = _isIncome ? _incomeCategories : _expenseCategories;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────
            _TopBar(
              onClose: () => context.pop(),
              isIncome: _isIncome,
              onToggle: (income) => setState(() {
                _isIncome = income;
                _category = income ? 'Salary' : 'Groceries';
                if (income) _bucket = 'mine';
              }),
            ),

            // ── Scrollable content ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bucket selector (hidden for income)
                    if (!_isIncome) ...[
                      _BucketSelector(
                        selected: _bucket,
                        onSelect: (b) => setState(() {
                          _bucket = b;
                          if (b != 'mine') _isPrivate = false;
                        }),
                      ),
                      const SizedBox(height: 20),
                    ] else
                      const SizedBox(height: 8),

                    // Amount field
                    _AmountField(controller: _amountController),

                    const SizedBox(height: 12),

                    // Merchant field
                    _MerchantField(
                      controller: _merchantController,
                      focusNode: _merchantFocus,
                      isIncome: _isIncome,
                    ),

                    const SizedBox(height: 12),

                    // Category chips
                    _CategoryChips(
                      categories: categories,
                      selected: _category,
                      icons: _categoryIcons,
                      color: bucketColor,
                      onSelect: (c) => setState(() => _category = c),
                    ),

                    const SizedBox(height: 12),

                    // Notes field (compact)
                    _NotesField(controller: _notesController),

                    // Private toggle (mine only)
                    if (_bucket == 'mine' && !_isIncome)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Private pocket',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            'Hidden from your partner',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          value: _isPrivate,
                          activeColor: AppColors.mine,
                          onChanged: (v) => setState(() => _isPrivate = v),
                        ),
                      ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(error: _error!),
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── Confirm button ────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                20, 8, 20,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: _ConfirmButton(
                canSubmit: _canSubmit,
                loading: _loading,
                showSuccess: _showSuccess,
                isIncome: _isIncome,
                color: bucketColor,
                onTap: _canSubmit ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Top bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  final bool isIncome;
  final ValueChanged<bool> onToggle;

  const _TopBar({
    required this.onClose,
    required this.isIncome,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.separatorOpaque,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            ),
            onPressed: onClose,
          ),

          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.separatorOpaque,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToggleTab(
                      label: 'Expense',
                      selected: !isIncome,
                      selectedColor: AppColors.destructive,
                      onTap: () => onToggle(false),
                    ),
                    _ToggleTab(
                      label: 'Income',
                      selected: isIncome,
                      selectedColor: AppColors.success,
                      onTap: () => onToggle(true),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 46), // balance close button
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                )]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? selectedColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Bucket selector ───────────────────────────────────────────────────────────

class _BucketSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _BucketSelector({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['mine', 'ours', 'theirs'].map((b) {
        final isSelected = b == selected;
        final color      = AppColors.forBucket(b);
        final lightColor = AppColors.lightForBucket(b);
        final label      = b[0].toUpperCase() + b.substring(1);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: b != 'theirs' ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(b);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? lightColor : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : AppColors.separatorOpaque,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isSelected ? color : AppColors.separator,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? color : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Amount field ──────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  const _AmountField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      style: GoogleFonts.inter(fontSize: 16, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Amount',
        labelStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        prefixText: '\$ ',
        prefixStyle: GoogleFonts.inter(fontSize: 16, color: AppColors.textPrimary),
        hintText: '0.00',
        hintStyle: GoogleFonts.inter(fontSize: 16, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.separatorOpaque),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.separatorOpaque),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.mine, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Enter an amount';
        if (double.tryParse(v) == null) return 'Enter a valid amount';
        return null;
      },
    );
  }
}

// ── Merchant field ────────────────────────────────────────────────────────────

class _MerchantField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isIncome;

  const _MerchantField({
    required this.controller,
    required this.focusNode,
    required this.isIncome,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: TextCapitalization.words,
      style: GoogleFonts.inter(
        fontSize: 16,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: isIncome ? 'Source (e.g. Employer)' : 'Merchant (e.g. Woolworths)',
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color: AppColors.textTertiary,
        ),
        prefixIcon: Icon(
          isIncome ? Icons.business_outlined : Icons.store_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.separatorOpaque),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.separatorOpaque),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.mine, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ── Category chips ────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final Map<String, IconData> icons;
  final Color color;
  final ValueChanged<String> onSelect;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.icons,
    required this.color,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat        = categories[i];
          final isSelected = cat == selected;
          final icon       = icons[cat] ?? Icons.label_outline;
          final lightColor = Color.lerp(color, Colors.white, 0.85)!;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? color : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : AppColors.separatorOpaque,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 13,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    cat,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
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

// ── Notes field ───────────────────────────────────────────────────────────────

class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  const _NotesField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
      maxLines: 1,
      decoration: InputDecoration(
        hintText: 'Notes (optional)',
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary),
        prefixIcon: const Icon(Icons.notes_outlined,
            size: 18, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.separatorOpaque),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.separatorOpaque),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.mine, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.destructive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confirm button ────────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  final bool canSubmit;
  final bool loading;
  final bool showSuccess;
  final bool isIncome;
  final Color color;
  final VoidCallback? onTap;

  const _ConfirmButton({
    required this.canSubmit,
    required this.loading,
    required this.showSuccess,
    required this.isIncome,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: canSubmit
              ? (showSuccess ? AppColors.success : color)
              : AppColors.separatorOpaque,
          borderRadius: BorderRadius.circular(14),
          boxShadow: canSubmit
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : showSuccess
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
                  : Text(
                      isIncome ? 'Add Income' : 'Add Expense',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: canSubmit ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
        ),
      ),
    );
  }
}

