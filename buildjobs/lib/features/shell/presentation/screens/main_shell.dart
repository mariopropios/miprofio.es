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

    return WebTapGuard(
      child: NavigationBar(
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
      ),
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

class _DesktopSideNav extends ConsumerWidget {
  const _DesktopSideNav({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(totalUnreadMessagesProvider);

    return WebTapGuard(
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _navigateShell(context, index),
        labelType: NavigationRailLabelType.all,
        minWidth: 108,
        leading: const Padding(
          padding: EdgeInsets.fromLTRB(14, 24, 14, 8),
          child: _DesktopRailBrand(),
        ),
        destinations: [
          const NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: Text('Inicio'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: Text('Buscar'),
          ),
          NavigationRailDestination(
            icon: _BadgedChatIcon(
              count: unreadCount,
              outlined: true,
            ),
            selectedIcon: _BadgedChatIcon(
              count: unreadCount,
              outlined: false,
            ),
            label: const Text('Mensajes'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Perfil'),
          ),
        ],
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
    final parts = AppConstants.appName.split('.');
    final name = parts.first;
    final domain =
        parts.length > 1 ? '.${parts.sublist(1).join('.')}' : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.construction, color: AppTheme.primary, size: 32),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppTheme.primary,
            height: 1.15,
            letterSpacing: -0.2,
          ),
        ),
        if (domain.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            domain,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.primary.withValues(alpha: 0.88),
              height: 1.1,
            ),
          ),
        ],
      ],
    );
  }
}

class _BadgedChatIcon extends StatelessWidget {
  const _BadgedChatIcon({
    required this.count,
    required this.outlined,
  });

  final int count;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      outlined ? Icons.chat_bubble_outline_rounded : Icons.chat_bubble_rounded,
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
