import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/currency_ext.dart';
import '../../../data/models/transaction.dart';
import '../../home/providers/home_provider.dart';
import '../providers/spending_provider.dart';
import '../../fair_split/providers/fair_split_provider.dart';
import '../../analytics/providers/analytics_provider.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../shared/providers/auth_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
// TransactionDetailSheet
// Purpose: Full metadata view for a single transaction, shown as a bottom
//          sheet. Amount is the hero element; metadata is in grouped sections
//          below. Includes a delete action.
// ════════════════════════════════════════════════════════════════════════════

/// Show the transaction detail bottom sheet.
void showTransactionDetail(BuildContext context, Transaction tx) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TransactionDetailSheet(tx: tx),
  );
}

class TransactionDetailSheet extends ConsumerStatefulWidget {
  final Transaction tx;
  const TransactionDetailSheet({super.key, required this.tx});

  @override
  ConsumerState<TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<TransactionDetailSheet> {
  bool    _deleting = false;
  String? _deleteError;

  // ── Edit ─────────────────────────────────────────────────────────────────

  Future<void> _showEditSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTransactionSheet(tx: widget.tx),
    );
    if (saved == true && mounted) Navigator.of(context).pop();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  IconData get _icon => switch (widget.tx.category) {
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
    'Salary'        => Icons.account_balance_outlined,
    _               => Icons.receipt_outlined,
  };

  String get _bucketLabel => switch (widget.tx.bucket) {
    'mine'   => 'My spending',
    'ours'   => 'Our spending',
    'theirs' => "Partner's spending",
    _        => widget.tx.bucket,
  };

  String get _formattedDate {
    try {
      final d = DateTime.parse(widget.tx.date);
      return DateFormat('EEEE, d MMMM yyyy').format(d);
    } catch (_) {
      return widget.tx.date;
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete transaction?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'This will permanently remove "${widget.tx.merchantName}" from your records.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, color: AppColors.destructive)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() { _deleting = true; _deleteError = null; });
    try {
      await ref.read(transactionRepoProvider).deleteTransaction(widget.tx.id);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(allTransactionsThisMonthProvider);
      ref.invalidate(spendingTransactionsProvider);
      ref.invalidate(oursTransactionsProvider);
      ref.invalidate(bucketTotalsProvider);
      ref.invalidate(monthlyTotalsProvider);
      ref.invalidate(lastMonthBucketBreakdownProvider);
      ref.invalidate(fairSplitResultProvider);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _deleting = false; _deleteError = e.toString(); });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color      = AppColors.forBucket(widget.tx.bucket);
    final lightColor = AppColors.lightForBucket(widget.tx.bucket);
    final bottomPad  = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.72, 0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.separator,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Scrollable content ───────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 16),
                  children: [
                    // ── Hero: amount + merchant ──────────────────────
                    _HeroSection(tx: widget.tx, color: color, lightColor: lightColor, icon: _icon),

                    const SizedBox(height: 20),

                    // ── Details card ──────────────────────────────────
                    _DetailCard(
                      rows: [
                        _DetailRow(
                          label: 'Date',
                          value: _formattedDate,
                          icon: Icons.calendar_today_outlined,
                        ),
                        _DetailRow(
                          label: 'Category',
                          value: widget.tx.category ?? 'Uncategorised',
                          icon: _icon,
                        ),
                        _DetailRow(
                          label: 'Bucket',
                          value: _bucketLabel,
                          icon: Icons.account_balance_wallet_outlined,
                          valueColor: color,
                          valueBgColor: lightColor,
                        ),
                        _DetailRow(
                          label: 'Type',
                          value: widget.tx.isIncome ? 'Income' : 'Expense',
                          icon: widget.tx.isIncome
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          valueColor: widget.tx.isIncome
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                        if (widget.tx.isPrivate)
                          _DetailRow(
                            label: 'Visibility',
                            value: 'Private pocket',
                            icon: Icons.lock_outline,
                            valueColor: AppColors.textSecondary,
                          ),
                      ],
                    ),

                    // ── Notes ─────────────────────────────────────────
                    if (widget.tx.notes != null && widget.tx.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _NotesCard(notes: widget.tx.notes!),
                    ],

                    const SizedBox(height: 24),

                    // ── Delete error ──────────────────────────────────
                    if (_deleteError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.destructive
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.destructive
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 16, color: AppColors.destructive),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _deleteError!,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.destructive),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Actions: Edit + Delete ────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _EditButton(onTap: _showEditSheet),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DeleteButton(
                              deleting: _deleting, onTap: _delete),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Hero section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final Transaction tx;
  final Color color;
  final Color lightColor;
  final IconData icon;

  const _HeroSection({
    required this.tx,
    required this.color,
    required this.lightColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final displayAmount = tx.isIncome
        ? '+${tx.amountAud.toAUD()}'
        : '-${tx.amountAud.abs().toAUD()}';

    return Column(
      children: [
        // Category icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: lightColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 26, color: color),
        ),
        const SizedBox(height: 14),

        // Amount — hero
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: tx.amountAud.abs()),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (context, value, _) {
            final sign = tx.isIncome ? '+' : '-';
            final formatted = value.toAUD();
            return Text(
              '$sign$formatted',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: tx.isIncome ? AppColors.success : AppColors.textPrimary,
                letterSpacing: -1,
              ),
            );
          },
        ),

        const SizedBox(height: 6),

        // Merchant name
        Text(
          tx.merchantName,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 4),

        // Bucket pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: lightColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                switch (tx.bucket) {
                  'mine'   => 'My spending',
                  'ours'   => 'Our spending',
                  'theirs' => "Partner's spending",
                  _        => tx.bucket,
                },
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Detail card ────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<_DetailRow> rows;
  const _DetailCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: rows.asMap().entries.map((entry) {
          final row    = entry.value;
          final isLast = entry.key == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(row.icon, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text(
                      row.label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (row.valueBgColor != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: row.valueBgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          row.value,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: row.valueColor ?? AppColors.textPrimary,
                          ),
                        ),
                      )
                    else
                      Text(
                        row.value,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: row.valueColor ?? AppColors.textPrimary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 46,
                  endIndent: 16,
                  color: AppColors.separatorOpaque,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DetailRow {
  final String   label;
  final String   value;
  final IconData icon;
  final Color?   valueColor;
  final Color?   valueBgColor;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.valueBgColor,
  });
}

// ── Notes card ─────────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final String notes;
  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_outlined,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Notes',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit button ───────────────────────────────────────────────────────────────

class _EditButton extends StatefulWidget {
  final VoidCallback onTap;
  const _EditButton({required this.onTap});

  @override
  State<_EditButton> createState() => _EditButtonState();
}

class _EditButtonState extends State<_EditButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.separatorOpaque
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.separatorOpaque),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Edit',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Delete button ──────────────────────────────────────────────────────────────

class _DeleteButton extends StatefulWidget {
  final bool deleting;
  final VoidCallback onTap;

  const _DeleteButton({required this.deleting, required this.onTap});

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.destructive.withValues(alpha: 0.08)
              : AppColors.destructive.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: widget.deleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.destructive,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.destructive),
                    const SizedBox(width: 8),
                    Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.destructive,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Edit transaction sheet ────────────────────────────────────────────────────

class _EditTransactionSheet extends ConsumerStatefulWidget {
  final Transaction tx;
  const _EditTransactionSheet({required this.tx});

  @override
  ConsumerState<_EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState
    extends ConsumerState<_EditTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _notesController;

  late String _bucket;
  late String _category;
  late bool   _isIncome;
  late bool   _isPrivate;
  bool        _loading = false;
  String?     _error;

  static const _expenseCategories = [
    'Groceries', 'Dining Out', 'Rent', 'Utilities', 'Transport',
    'Clothing', 'Health', 'Entertainment', 'Streaming', 'Subscriptions',
    'Food Delivery', 'Travel', 'Insurance', 'Other',
  ];

  static const _incomeCategories = [
    'Salary', 'Freelance', 'Rental Income',
    'Investment Return', 'Gift', 'Refund', 'Other Income',
  ];

  static const _categoryIcons = <String, IconData>{
    'Groceries':         Icons.shopping_basket_outlined,
    'Dining Out':        Icons.restaurant_outlined,
    'Rent':              Icons.home_outlined,
    'Utilities':         Icons.bolt_outlined,
    'Transport':         Icons.directions_car_outlined,
    'Clothing':          Icons.checkroom_outlined,
    'Health':            Icons.favorite_outline,
    'Entertainment':     Icons.movie_outlined,
    'Streaming':         Icons.play_circle_outline,
    'Subscriptions':     Icons.subscriptions_outlined,
    'Food Delivery':     Icons.delivery_dining_outlined,
    'Travel':            Icons.flight_outlined,
    'Insurance':         Icons.security_outlined,
    'Other':             Icons.more_horiz_outlined,
    'Salary':            Icons.account_balance_outlined,
    'Freelance':         Icons.laptop_outlined,
    'Rental Income':     Icons.home_work_outlined,
    'Investment Return': Icons.trending_up_outlined,
    'Gift':              Icons.card_giftcard_outlined,
    'Refund':            Icons.replay_outlined,
    'Other Income':      Icons.attach_money_outlined,
  };

  @override
  void initState() {
    super.initState();
    final tx = widget.tx;
    _amountController   = TextEditingController(
        text: tx.amountAud.toStringAsFixed(2));
    _merchantController = TextEditingController(text: tx.merchantName);
    _notesController    = TextEditingController(text: tx.notes ?? '');
    _bucket    = tx.bucket;
    _category  = tx.category ?? 'Other';
    _isIncome  = tx.isIncome;
    _isPrivate = tx.isPrivate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (_merchantController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a merchant name');
      return;
    }

    if (_bucket != 'mine') {
      final partners = await ref.read(partnersProvider.future);
      if (partners.length < 2) {
        setState(() {
          _error = _bucket == 'ours'
              ? 'Invite your partner first to use shared expenses.'
              : 'Invite your partner first to use their expenses.';
        });
        return;
      }
    }

    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(transactionRepoProvider).updateTransaction(
        transactionId: widget.tx.id,
        amountAud:     amount,
        merchantName:  _merchantController.text.trim(),
        bucket:        _bucket,
        category:      _category,
        isIncome:      _isIncome,
        isPrivate:     _isPrivate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(allTransactionsThisMonthProvider);
      ref.invalidate(spendingTransactionsProvider);
      ref.invalidate(oursTransactionsProvider);
      ref.invalidate(bucketTotalsProvider);
      ref.invalidate(monthlyTotalsProvider);
      ref.invalidate(lastMonthBucketBreakdownProvider);
      ref.invalidate(fairSplitResultProvider);

      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories  = _isIncome ? _incomeCategories : _expenseCategories;
    final bucketColor = AppColors.forBucket(_bucket);
    final hasPartner  = ref.watch(partnersProvider).maybeWhen(
      data: (p) => p.length >= 2,
      orElse: () => false,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle + header
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  'Edit transaction',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Income / Expense toggle
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.separatorOpaque,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MiniToggle(
                        label: 'Expense',
                        selected: !_isIncome,
                        color: AppColors.destructive,
                        onTap: () => setState(() {
                          _isIncome = false;
                          if (!_expenseCategories.contains(_category)) {
                            _category = 'Other';
                          }
                        }),
                      ),
                      _MiniToggle(
                        label: 'Income',
                        selected: _isIncome,
                        color: AppColors.success,
                        onTap: () => setState(() {
                          _isIncome = true;
                          _bucket = 'mine';
                          if (!_incomeCategories.contains(_category)) {
                            _category = 'Other Income';
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bucket selector (expense only)
            if (!_isIncome) ...[
              _EditBucketSelector(
                selected: _bucket,
                hasPartner: hasPartner,
                onSelect: (b) => setState(() {
                  _bucket = b;
                  if (b != 'mine') _isPrivate = false;
                }),
              ),
              const SizedBox(height: 14),
            ],

            // Amount
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(
                  fontSize: 16, color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary),
                prefixText: '\$ ',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.separatorOpaque),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.separatorOpaque),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: bucketColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Merchant
            TextField(
              controller: _merchantController,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(
                  fontSize: 16, color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: _isIncome ? 'Source' : 'Merchant',
                labelStyle: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.separatorOpaque),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.separatorOpaque),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: bucketColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Category chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat        = categories[i];
                  final isSelected = cat == _category;
                  final icon = _categoryIcons[cat] ?? Icons.label_outline;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _category = cat);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? bucketColor
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? bucketColor
                              : AppColors.separatorOpaque,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              size: 13,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            cat,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesController,
              maxLines: 1,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Notes (optional)',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.notes_outlined,
                    size: 18, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.separatorOpaque),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.separatorOpaque),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: bucketColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),

            // Private toggle
            if (_bucket == 'mine' && !_isIncome)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Private pocket',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textPrimary)),
                subtitle: Text('Hidden from your partner',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                value: _isPrivate,
                activeColor: AppColors.mine,
                onChanged: (v) => setState(() => _isPrivate = v),
              ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          AppColors.destructive.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppColors.destructive),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.destructive)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: bucketColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text('Save changes',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mini toggle (income/expense) ──────────────────────────────────────────────

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _MiniToggle({
    required this.label,
    required this.selected,
    required this.color,
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
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Edit bucket selector ──────────────────────────────────────────────────────

class _EditBucketSelector extends StatelessWidget {
  final String selected;
  final bool hasPartner;
  final ValueChanged<String> onSelect;

  const _EditBucketSelector({
    required this.selected,
    required this.hasPartner,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['mine', 'ours', 'theirs'].map((b) {
        final isSelected   = b == selected;
        final needsPartner = b != 'mine' && !hasPartner;
        final color        = AppColors.forBucket(b);
        final lightColor   = AppColors.lightForBucket(b);
        final label        = b[0].toUpperCase() + b.substring(1);

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: b != 'theirs' ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(b);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? lightColor : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : AppColors.separatorOpaque,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : AppColors.separator,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? color
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (needsPartner) ...[
                      const SizedBox(height: 2),
                      Text(
                        'needs partner',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
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
