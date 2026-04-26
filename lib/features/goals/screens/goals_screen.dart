import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/currency_ext.dart';
import '../../../data/models/goal.dart';
import '../providers/goals_provider.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/subscription_provider.dart';
import '../../../data/services/analytics_service.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);
    final isFreeAsync = ref.watch(isFreeProvider);

    final canCreate = goalsAsync.maybeWhen(
      data: (goals) => isFreeAsync.maybeWhen(
        data: (isFree) => !isFree || goals.length < 3,
        orElse: () => true,
      ),
      orElse: () => true,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Goals',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => canCreate
                  ? _showCreateGoalSheet(context, ref)
                  : context.push('/paywall'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.ours,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ours.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'New',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 20),
                    Text(
                      'No goals yet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set a savings goal and work towards it together.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => canCreate
                          ? _showCreateGoalSheet(context, ref)
                          : context.push('/paywall'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1D9E75), Color(0xFF158A65)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF1D9E75).withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Create your first goal',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 200),
            itemCount: goals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _GoalCard(goal: goals[i]),
          );
        },
      ),
    );
  }

  void _showCreateGoalSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateGoalSheet(),
    );
  }
}

// ── Goal card ─────────────────────────────────────────────────────────────────

class _GoalCard extends ConsumerWidget {
  final Goal goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(goalContributionTotalsProvider(goal.id));
    return _buildCard(context, ref, totalsAsync);
  }

  Widget _buildCard(BuildContext context, WidgetRef ref,
      AsyncValue<Map<String, double>> totalsAsync) {
    return totalsAsync.when(
      loading: () => _GoalCardShell(goal: goal, partnerATot: 0, partnerBTotal: 0),
      error: (_, __) => _GoalCardShell(goal: goal, partnerATot: 0, partnerBTotal: 0),
      data: (totals) {
        final entries = totals.entries.toList();
        final partnerATot = entries.isNotEmpty ? entries[0].value : 0.0;
        final partnerBTot = entries.length > 1 ? entries[1].value : 0.0;
        return _GoalCardShell(
          goal: goal,
          partnerATot: partnerATot,
          partnerBTotal: partnerBTot,
          onAddContribution: () => _showAddContribution(context, ref),
          onLongPress: () => _showGoalActions(context, ref),
        );
      },
    );
  }

  void _showGoalActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text('Edit goal',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => _EditGoalSheet(goal: goal),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: Text('Delete goal',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete "${goal.name}"?',
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700)),
                      content: Text(
                        'This will remove the goal and its progress.',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref
                                .read(goalsNotifierProvider.notifier)
                                .deleteGoal(goal.id);
                          },
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.redAccent),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddContribution(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddContributionSheet(goal: goal),
    );
  }
}

class _GoalCardShell extends StatelessWidget {
  final Goal goal;
  final double partnerATot;
  final double partnerBTotal;
  final VoidCallback? onAddContribution;
  final VoidCallback? onLongPress;

  const _GoalCardShell({
    required this.goal,
    this.partnerATot = 0,
    required this.partnerBTotal,
    this.onAddContribution,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final total = partnerATot + partnerBTotal;
    final progress = goal.targetAmountAud > 0
        ? (total / goal.targetAmountAud).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progress * 100).round();

    String? daysLeft;
    if (goal.targetDate != null) {
      final target = DateTime.parse(goal.targetDate!);
      final diff = target.difference(DateTime.now()).inDays;
      daysLeft = diff > 0 ? '$diff days left' : 'Past due';
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (goal.emoji != null)
                  Text(goal.emoji!,
                      style: const TextStyle(fontSize: 24)),
                if (goal.emoji != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(goal.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                Text('$percent%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ours)),
              ],
            ),
            const SizedBox(height: 12),

            // Dual contribution bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(
                      height: 8, color: Colors.grey.shade100),
                  Row(
                    children: [
                      Flexible(
                        flex: (partnerATot * 1000).round(),
                        child: Container(
                            height: 8, color: AppColors.mine),
                      ),
                      Flexible(
                        flex: (partnerBTotal * 1000).round(),
                        child: Container(
                            height: 8, color: AppColors.theirs),
                      ),
                      Flexible(
                        flex: ((goal.targetAmountAud - total).clamp(0, goal.targetAmountAud) * 1000).round(),
                        child: Container(
                            height: 8,
                            color: Colors.grey.shade100),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: AppColors.mine,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(partnerATot.toAUD(showCents: false),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.mineDark)),
                    const SizedBox(width: 12),
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: AppColors.theirs,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(partnerBTotal.toAUD(showCents: false),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.theirsDark)),
                  ],
                ),
                Text(
                  '${total.toAUD(showCents: false)} of ${goal.targetAmountAud.toAUD(showCents: false)}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),

            if (daysLeft != null) ...[
              const SizedBox(height: 4),
              Text(daysLeft,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400)),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAddContribution,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.ours),
                  foregroundColor: AppColors.ours,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Add contribution'),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

// ── Edit goal sheet ───────────────────────────────────────────────────────────

class _EditGoalSheet extends ConsumerStatefulWidget {
  final Goal goal;
  const _EditGoalSheet({required this.goal});

  @override
  ConsumerState<_EditGoalSheet> createState() => _EditGoalSheetState();
}

class _EditGoalSheetState extends ConsumerState<_EditGoalSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String _selectedEmoji;
  bool _loading = false;

  final _emojis = ['🎯', '✈️', '🏠', '🚗', '💍', '👶', '🛡️', '🏦', '🎓', '💰'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.name);
    _amountController = TextEditingController(
        text: widget.goal.targetAmountAud.toStringAsFixed(0));
    _selectedEmoji = widget.goal.emoji ?? '🎯';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _loading = true);
    await ref.read(goalsNotifierProvider.notifier).updateGoal(
      goalId: widget.goal.id,
      name: _nameController.text.trim(),
      targetAmountAud: amount,
      emoji: _selectedEmoji,
      targetDate: widget.goal.targetDate,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit goal',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Emoji picker
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _emojis.length,
              itemBuilder: (_, i) {
                final e = _emojis[i];
                final selected = e == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.oursLight
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(color: AppColors.ours)
                          : null,
                    ),
                    child: Center(
                        child: Text(e,
                            style: const TextStyle(fontSize: 20))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Goal name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Target amount',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ours,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add contribution sheet ────────────────────────────────────────────────────

class _AddContributionSheet extends ConsumerStatefulWidget {
  final Goal goal;
  const _AddContributionSheet({required this.goal});

  @override
  ConsumerState<_AddContributionSheet> createState() =>
      _AddContributionSheetState();
}

class _AddContributionSheetState
    extends ConsumerState<_AddContributionSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _loading = true);
    await ref.read(goalsNotifierProvider.notifier).addContribution(
      goalId: widget.goal.id,
      amountAud: amount,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add to ${widget.goal.name}',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ours,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Add contribution'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create goal sheet ─────────────────────────────────────────────────────────

class _CreateGoalSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends ConsumerState<_CreateGoalSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedEmoji = '🎯';
  String _splitMethod = 'fifty_fifty';
  bool _loading = false;

  final _emojis = ['🎯', '✈️', '🏠', '🚗', '💍', '👶', '🛡️', '🏦', '🎓', '💰'];

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) return;
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _loading = true);
    await ref.read(goalsNotifierProvider.notifier).createGoal(
      name: _nameController.text.trim(),
      targetAmountAud: amount,
      emoji: _selectedEmoji,
      contributionSplit: _splitMethod,
      contributionRatioA: _splitMethod == 'fifty_fifty' ? 0.5 : 0.55,
    );
    await AnalyticsService.goalCreated();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New goal',
              style:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),

          // Emoji picker
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _emojis.length,
              itemBuilder: (_, i) {
                final e = _emojis[i];
                final selected = e == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.oursLight
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(color: AppColors.ours)
                          : null,
                    ),
                    child: Center(
                        child: Text(e,
                            style: const TextStyle(fontSize: 20))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Goal name',
              hintText: 'e.g. Europe holiday',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Target amount',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // Split method
          DropdownButtonFormField<String>(
            value: _splitMethod,
            decoration: const InputDecoration(
              labelText: 'How to split contributions',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'fifty_fifty', child: Text('50 / 50')),
              DropdownMenuItem(
                  value: 'income_ratio',
                  child: Text('By income ratio')),
              DropdownMenuItem(
                  value: 'custom', child: Text('Custom')),
            ],
            onChanged: (v) => setState(() => _splitMethod = v!),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ours,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Create goal'),
            ),
          ),
        ],
      ),
    );
  }
}