import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/currency_ext.dart';
import '../../../data/repositories/household_repository.dart';
import '../../../data/repositories/goal_repository.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../fair_split/providers/fair_split_provider.dart';
import '../../goals/providers/goals_provider.dart';

class RelationshipStatusScreen extends ConsumerStatefulWidget {
  const RelationshipStatusScreen({super.key});

  @override
  ConsumerState<RelationshipStatusScreen> createState() =>
      _RelationshipStatusScreenState();
}

class _RelationshipStatusScreenState
    extends ConsumerState<RelationshipStatusScreen> {
  bool _loading = false;
  String? _error;
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pauseHousehold() async {
    final household = await ref.read(householdRepoProvider).fetchMyHousehold();
    final partners = await ref.read(partnersProvider.future);
    final userId = ref.read(authUserProvider).value?.id;
    final me = partners.where((p) => p.userId == userId).firstOrNull;

    if (household == null || me == null) return;

    setState(() { _loading = true; _error = null; });

    try {
      await ref.read(householdRepoProvider).pauseHousehold(
        householdId: household.id,
        partnerId: me.id,
        reason: _reasonController.text.isEmpty
            ? null
            : _reasonController.text,
      );
      ref.invalidate(householdProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Household paused — your data is safe'),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resumeHousehold() async {
    final household = await ref.read(householdRepoProvider).fetchMyHousehold();
    final partners = await ref.read(partnersProvider.future);
    final userId = ref.read(authUserProvider).value?.id;
    final me = partners.where((p) => p.userId == userId).firstOrNull;

    if (household == null || me == null) return;

    setState(() { _loading = true; _error = null; });

    try {
      await ref.read(householdRepoProvider).resumeHousehold(
        householdId: household.id,
        partnerId: me.id,
      );
      ref.invalidate(householdProvider);
      ref.invalidate(goalsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome back! Goals resumed.')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdAsync = ref.watch(householdProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        title: const Text('Relationship status'),
      ),
      body: householdAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (household) {
          if (household == null) return const SizedBox.shrink();

          if (household.isPaused) {
            return _ResumeView(
              household: household,
              loading: _loading,
              error: _error,
              onResume: _resumeHousehold,
            );
          }

          return _PauseView(
            reasonController: _reasonController,
            loading: _loading,
            error: _error,
            onPause: () => _showPauseConfirmation(context),
          );
        },
      ),
    );
  }

  void _showPauseConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pause household?'),
        content: const Text(
          'This will pause all shared goals and stop fair split tracking. '
          'Your individual data stays safe. You can resume anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _pauseHousehold();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Pause household'),
          ),
        ],
      ),
    );
  }
}

// ── Pause view (active household) ─────────────────────────────────────────────

class _PauseView extends StatelessWidget {
  final TextEditingController reasonController;
  final bool loading;
  final String? error;
  final VoidCallback onPause;

  const _PauseView({
    required this.reasonController,
    required this.loading,
    required this.error,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pause_circle_outline,
                        color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text('Taking a break?',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pausing your household will:\n'
                  '• Freeze all shared goals\n'
                  '• Stop fair split tracking\n'
                  '• Keep all your data safe\n'
                  '• Allow you to withdraw your goal contributions',
                  style: TextStyle(
                      fontSize: 13, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('Reason (optional)',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: 'Taking some time apart...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),

          if (error != null) ...[
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: loading ? null : onPause,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.red)
                  : const Text('Pause household',
                      style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Resume view (paused household) ────────────────────────────────────────────

class _ResumeView extends StatelessWidget {
  final dynamic household;
  final bool loading;
  final String? error;
  final VoidCallback onResume;

  const _ResumeView({
    required this.household,
    required this.loading,
    required this.error,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.oursLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.ours),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.favorite_outline, color: AppColors.ours),
                    const SizedBox(width: 8),
                    Text('Ready to reconnect?',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.oursDark)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your household is currently paused. '
                  'Resuming will:\n'
                  '• Restart all shared goals from where you left off\n'
                  '• Resume fair split tracking\n'
                  '• All previous contributions are preserved',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.oursDark),
                ),
                if (household.pauseReason != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Pause reason: ${household.pauseReason}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.oursDark,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          if (error != null) ...[
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : onResume,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ours,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.favorite, color: Colors.white),
              label: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Resume household',
                      style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}