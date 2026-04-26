import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/revenue_cat_service.dart';
import '../../../data/services/analytics_service.dart';

final packagesProvider = FutureProvider<List<Package>>((ref) {
  return RevenueCatService.getPackages();
});

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;
  String? _error;
  String _selectedTier = 'together';

  @override
  void initState() {
    super.initState();
    AnalyticsService.paywallViewed('upgrade_button');
  }

  Future<void> _purchase(Package package) async {
    setState(() { _loading = true; _error = null; });
    try {
      final info = await RevenueCatService.purchase(package);
      if (info.entitlements.active.isNotEmpty) {
        await AnalyticsService.subscriptionPurchased(_selectedTier);
        if (mounted) context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Purchase failed — please try again');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() { _loading = true; _error = null; });
    try {
      final info = await RevenueCatService.restorePurchases();
      if (info.entitlements.active.isNotEmpty) {
        await AnalyticsService.subscriptionRestored();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchases restored')),
          );
          context.go('/home');
        }
      } else {
        setState(() => _error = 'No purchases found to restore');
      }
    } catch (e) {
      setState(() => _error = 'Restore failed — please try again');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packagesAsync = ref.watch(packagesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Upgrade TwoWallet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'One subscription covers both partners.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            // Tier selector
            _TierCard(
              title: 'Together',
              price: '\$12/mo or \$99/yr',
              color: AppColors.ours,
              lightColor: AppColors.oursLight,
              selected: _selectedTier == 'together',
              onTap: () => setState(() => _selectedTier = 'together'),
              features: [
                'Unlimited bank sync via Basiq',
                'Auto transaction categorisation',
                'Fair-split with bank sync',
                'Unlimited shared goals',
                'Full Money Date — AI talking points',
                'Subscription audit',
                'CSV export',
              ],
            ),
            const SizedBox(height: 12),
            _TierCard(
              title: 'Together+',
              price: '\$18/mo or \$149/yr',
              color: AppColors.mine,
              lightColor: AppColors.mineLight,
              selected: _selectedTier == 'together_plus',
              onTap: () => setState(() => _selectedTier = 'together_plus'),
              features: [
                'Everything in Together',
                'Income ratio re-balancer',
                'Cash flow forecast 30/90 day',
                'HECS/HELP debt tracker',
                'Super balance tracking',
                'Bill calendar',
                'Priority support',
              ],
            ),
            const SizedBox(height: 32),

            // Purchase button
            packagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _PurchaseButton(
                label: 'Start 30-day free trial',
                color: AppColors.ours,
                loading: _loading,
                onTap: () {},
              ),
              data: (packages) {
                final filtered = packages.where((p) {
                  if (_selectedTier == 'together') {
                    return p.storeProduct.identifier
                        .contains('together') &&
                        !p.storeProduct.identifier.contains('plus');
                  }
                  return p.storeProduct.identifier.contains('plus');
                }).toList();

                final package = filtered.isNotEmpty ? filtered.first : null;

                return _PurchaseButton(
                  label: 'Start 30-day free trial',
                  color: _selectedTier == 'together'
                      ? AppColors.ours
                      : AppColors.mine,
                  loading: _loading,
                  onTap: package != null ? () => _purchase(package) : null,
                );
              },
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center),
            ],

            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _loading ? null : _restore,
                child: Text('Restore purchases',
                    style: TextStyle(color: Colors.grey.shade500)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Cancel anytime. Billed in AUD. Both partners included.',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String title;
  final String price;
  final Color color;
  final Color lightColor;
  final bool selected;
  final VoidCallback onTap;
  final List<String> features;

  const _TierCard({
    required this.title,
    required this.price,
    required this.color,
    required this.lightColor,
    required this.selected,
    required this.onTap,
    required this.features,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? lightColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : Colors.black87)),
                if (selected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Selected',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(price,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _PurchaseButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;

  const _PurchaseButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}