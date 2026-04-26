import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/analytics_service.dart';

class InviteScreen extends ConsumerWidget {
  final String householdId;
  const InviteScreen({super.key, required this.householdId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteLink = AuthService().generateInviteLink(householdId);

    return Scaffold(
      appBar: AppBar(title: const Text('Invite your partner')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send this link to your partner',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'They\'ll tap it to join your household. Both of you need to be set up before bank sync works.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inviteLink,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite link copied')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share invite link'),
                onPressed: () async {
                  AnalyticsService.partnerInvited();
                  try {
                    final box = context.findRenderObject() as RenderBox?;
                    final sharePositionOrigin = box != null
                        ? box.localToGlobal(Offset.zero) & box.size
                        : null;
                    await Share.share(
                      'Join my TwoWallet household! Tap the link to get started: $inviteLink',
                      subject: 'Join me on TwoWallet',
                      sharePositionOrigin: sharePositionOrigin,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not share: $e')),
                      );
                    }
                  }
                },
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Continue without partner for now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}