import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/services/push_notification_clear.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../chat/presentation/providers/chat_providers.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/web_tap_guard.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(conversationsRealtimeProvider);

    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexForLocation(location);

    ref.listen<int>(totalUnreadMessagesProvider, (prev, next) {
      updatePushBadgeCount(next);
    });

    return ResponsiveLayout(
      mobile: _MobileShell(
        selectedIndex: selectedIndex,
        hideBottomNav: AppRoutes.isChatDetailLocation(location),
        child: child,
      ),
      desktop: _DesktopShell(
        selectedIndex: selectedIndex,
        child: child,
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith(AppRoutes.search)) return 1;
    if (location.startsWith(AppRoutes.conversations)) return 2;
    if (location.startsWith(AppRoutes.profile)) return 3;
    return 0;
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.hideBottomNav,
    required this.child,
  });

  final int selectedIndex;
  final bool hideBottomNav;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: hideBottomNav
          ? null
          : _MobileBottomNav(selectedIndex: selectedIndex),
    );
  }
}

class _MobileBottomNav extends ConsumerWidget {
  const _MobileBottomNav({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(totalUnreadMessagesProvider);

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => _navigateShell(context, index),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        const NavigationDestination(
          icon: Icon(Icons.search),
          selectedIcon: Icon(Icons.search),
          label: 'Buscar',
        ),
        NavigationDestination(
          icon: _BadgedChatIcon(
            count: unreadCount,
            outlined: true,
          ),
          selectedIcon: _BadgedChatIcon(
            count: unreadCount,
            outlined: false,
          ),
          label: 'Mensajes',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.selectedIndex,
    required this.child,
  });

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Row(
        children: [
          _DesktopSideNav(selectedIndex: selectedIndex),
          const VerticalDivider(width: 1, color: AppTheme.divider),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Sidebar custom de escritorio: ritmo vertical repartido (sin rail apelotonado).
class _DesktopSideNav extends ConsumerWidget {
  const _DesktopSideNav({required this.selectedIndex});

  final int selectedIndex;

  static const double _width = 248;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(totalUnreadMessagesProvider);

    return WebTapGuard(
      child: Material(
        color: AppTheme.surface,
        child: SizedBox(
          width: _width,
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DesktopRailBrand(),
                  const SizedBox(height: 28),
                  _DesktopNavTile(
                    selected: selectedIndex == 0,
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Inicio',
                    onTap: () => _navigateShell(context, 0),
                  ),
                  const SizedBox(height: 8),
                  _DesktopNavTile(
                    selected: selectedIndex == 1,
                    icon: Icons.search,
                    selectedIcon: Icons.search,
                    label: 'Buscar',
                    onTap: () => _navigateShell(context, 1),
                  ),
                  const SizedBox(height: 8),
                  _DesktopNavTile(
                    selected: selectedIndex == 2,
                    icon: Icons.chat_bubble_outline_rounded,
                    selectedIcon: Icons.chat_bubble_rounded,
                    label: 'Mensajes',
                    badgeCount: unreadCount,
                    onTap: () => _navigateShell(context, 2),
                  ),
                  const SizedBox(height: 8),
                  _DesktopNavTile(
                    selected: selectedIndex == 3,
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Perfil',
                    onTap: () => _navigateShell(context, 3),
                  ),
                  const SizedBox(height: 32),
                  const Divider(height: 1, color: AppTheme.divider),
                  const SizedBox(height: 16),
                  const _DesktopLegalLinks(),
                  // El hueco restante queda debajo del bloque (no entre nav y legales).
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavTile extends StatelessWidget {
  const _DesktopNavTile({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppTheme.primary : AppTheme.textSecondary;
    final bg = selected
        ? AppTheme.primary.withValues(alpha: 0.14)
        : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppTheme.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              _BadgedChatIcon(
                count: badgeCount,
                outlined: !selected,
                iconOverride: selected ? selectedIcon : icon,
                color: fg,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.1,
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

void _navigateShell(BuildContext context, int index) {
  switch (index) {
    case 0:
      context.go(AppRoutes.home);
    case 1:
      context.go(AppRoutes.search);
    case 2:
      context.go(AppRoutes.conversations);
    case 3:
      context.go(AppRoutes.profile);
  }
}

class _DesktopRailBrand extends StatelessWidget {
  const _DesktopRailBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(
            Icons.construction,
            color: AppTheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: Text(
            AppConstants.appName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: AppTheme.primary,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopLegalLinks extends StatelessWidget {
  const _DesktopLegalLinks();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      height: 1.4,
    );

    Widget link(String label, String route) {
      return InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(6),
        hoverColor: AppTheme.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(label, style: style),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        link('Acerca de', AppRoutes.about),
        link('Privacidad', AppRoutes.privacy),
        link('Cookies', AppRoutes.cookies),
        link('Términos', AppRoutes.terms),
        link('Aviso legal', AppRoutes.legalNotice),
      ],
    );
  }
}

class _BadgedChatIcon extends StatelessWidget {
  const _BadgedChatIcon({
    required this.count,
    required this.outlined,
    this.iconOverride,
    this.color,
  });

  final int count;
  final bool outlined;
  final IconData? iconOverride;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      iconOverride ??
          (outlined
              ? Icons.chat_bubble_outline_rounded
              : Icons.chat_bubble_rounded),
      color: color,
      size: 22,
    );

    if (count <= 0) return icon;

    return Badge(
      isLabelVisible: true,
      backgroundColor: AppTheme.primary,
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: icon,
    );
  }
}
