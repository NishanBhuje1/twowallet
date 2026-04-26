import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/analytics_service.dart';
import '../../../shared/providers/auth_provider.dart';

class InvitePartnerCard extends ConsumerStatefulWidget {
  const InvitePartnerCard({super.key});

  @override
  ConsumerState<InvitePartnerCard> createState() => _InvitePartnerCardState();
}

class _InvitePartnerCardState extends ConsumerState<InvitePartnerCard> {
  bool _minimised = false;

  Future<void> _shareLink(String householdId) async {
    final link = AuthService().generateInviteLink(householdId);
    AnalyticsService.partnerInvited();
    try {
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await Share.share(
        'Join my TwoWallet household! Tap the link to get started: $link',
        subject: 'Join me on TwoWallet',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  Future<void> _copyLink(String householdId) async {
    final link = AuthService().generateInviteLink(householdId);
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite link copied')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final partnersAsync = ref.watch(partnersProvider);

    return partnersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (partners) {
        final userId = Supabase.instance.client.auth.currentUser?.id;

        if (partners.length >= 2) {
          final other = partners.where((p) => p.userId != userId).firstOrNull;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1D9E75).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Color(0xFF1D9E75), size: 18),
                const SizedBox(width: 8),
                Text(
                  other != null
                      ? 'Connected with ${other.displayName}'
                      : 'Both partners connected',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D9E75),
                  ),
                ),
              ],
            ),
          );
        }

        final me = partners.where((p) => p.userId == userId).firstOrNull;
        final householdId = me?.householdId ?? '';

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _minimised ? 0.45 : 1.0,
          child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1D9E75),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // ── Header row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Invite your partner',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _minimised = !_minimised),
                      child: Icon(
                        _minimised
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              if (!_minimised) ...[
                // ── Subtitle ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Text(
                    'TwoWallet works best when both partners are connected.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Two action buttons ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _shareLink(householdId),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1D9E75),
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.ios_share, size: 16, color: Color(0xFF1D9E75)),
                              const SizedBox(width: 6),
                              Text(
                                'Share link',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _copyLink(householdId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                                color: Colors.white, width: 1.5),
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'Copy link',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
              ],
            ],
          ),
        ));
      },
    );
  }
}
