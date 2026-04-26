import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Nav bar container — RepaintBoundary isolates repaints to
              // just the changed _NavItem instead of the whole Scaffold.
              RepaintBoundary(
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      selected: index == 0,
                      onTap: () => navigationShell.goBranch(0,
                          initialLocation: index == 0),
                    ),
                    _NavItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'Spending',
                      selected: index == 1,
                      onTap: () => navigationShell.goBranch(1,
                          initialLocation: index == 1),
                    ),
                    // Empty center space for FAB
                    const Expanded(child: SizedBox()),
                    _NavItem(
                      icon: Icons.flag_outlined,
                      activeIcon: Icons.flag_rounded,
                      label: 'Goals',
                      selected: index == 3,
                      onTap: () => navigationShell.goBranch(3,
                          initialLocation: index == 3),
                    ),
                    _NavItem(
                      icon: Icons.bar_chart_outlined,
                      activeIcon: Icons.bar_chart_rounded,
                      label: 'Analytics',
                      selected: index == 4,
                      onTap: () => navigationShell.goBranch(4,
                          initialLocation: index == 4),
                    ),
                  ],
                ),
              ),
              ), // RepaintBoundary
              // Center FAB floating above nav bar
              Positioned(
                top: -20,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => context.push('/add-transaction'),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.ours,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ours.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.ours.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 18,
                color: selected ? AppColors.ours : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.ours : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
