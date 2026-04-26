import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../fair_split/providers/fair_split_provider.dart';
import '../../../shared/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: 'Privacy'),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text('Private pocket allowance',
                  style: GoogleFonts.inter(fontSize: 14)),
              subtitle: Text('Your monthly no-questions-asked budget',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade500)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPocketEditor(context, ref),
            ),
          ),
          _SectionHeader(title: 'Schedule'),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text('Money Date schedule',
                  style: GoogleFonts.inter(fontSize: 14)),
              subtitle: Text('Set your weekly check-in time',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade500)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/notification-settings'),
            ),
          ),
          _SectionHeader(title: 'Relationship'),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: Text('Relationship status',
                  style: GoogleFonts.inter(fontSize: 14)),
              subtitle: Text('Pause or resume your household',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade500)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/relationship-status'),
            ),
          ),
          _SectionHeader(title: 'Account'),
          Container(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Delete account',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.red)),
              subtitle: Text('Permanently delete your account and all data',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey.shade500)),
              onTap: () => launchUrl(
                Uri.parse('https://twowallet.app/delete-account'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPocketEditor(BuildContext context, WidgetRef ref) async {
    final household = await ref.read(householdRepoProvider).fetchMyHousehold();
    if (household == null || !context.mounted) return;

    final partners = await ref.read(partnersProvider.future);
    final userId = ref.read(authUserProvider).value?.id;
    final me = partners.where((p) => p.userId == userId).firstOrNull;
    if (me == null || !context.mounted) return;

    final isPartnerA = me.role == 'partner_a';
    final currentAmount = isPartnerA
        ? household.privatePocketAAud
        : household.privatePocketBAud;

    final controller =
        TextEditingController(text: currentAmount.toStringAsFixed(0));

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        bool loading = false;
        return StatefulBuilder(
          builder: (innerCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(innerCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Private pocket allowance',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set your monthly no-questions-asked budget',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monthly allowance',
                      prefixText: '\$ ',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1D9E75), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: loading
                          ? null
                          : () async {
                              final amount =
                                  double.tryParse(controller.text);
                              if (amount == null || amount < 0) return;
                              setSheetState(() => loading = true);
                              try {
                                await ref
                                    .read(householdRepoProvider)
                                    .updatePrivatePockets(
                                      pocketA: isPartnerA
                                          ? amount
                                          : household.privatePocketAAud,
                                      pocketB: isPartnerA
                                          ? household.privatePocketBAud
                                          : amount,
                                    );
                                ref.invalidate(householdProvider);
                                if (innerCtx.mounted) {
                                  Navigator.pop(innerCtx);
                                }
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content:
                                          const Text('Allowance updated'),
                                      backgroundColor: AppColors.ours,
                                    ),
                                  );
                                }
                              } catch (_) {
                                setSheetState(() => loading = false);
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ours,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Save',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
