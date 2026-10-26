import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme/theme_mode_controller.dart';
import '../features/auth/controllers/auth_controller.dart';

class AppNavigationScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final int selectedIndex;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final String? subtitle;
  final bool showBackButton;
  final bool showGuestActions;

  const AppNavigationScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.selectedIndex,
    this.actions,
    this.floatingActionButton,
    this.subtitle,
    this.showBackButton = false,
    this.showGuestActions = true,
  });

  static const _destinations = [
    _NavDestination(
      Icons.dashboard_outlined,
      Icons.dashboard_rounded,
      'Home',
      '/',
    ),
    _NavDestination(
      Icons.cloud_outlined,
      Icons.cloud_rounded,
      'Weather',
      '/weather',
    ),
    _NavDestination(
      Icons.agriculture_outlined,
      Icons.agriculture_rounded,
      'Farms',
      '/farms',
    ),
    _NavDestination(
      Icons.sensors_outlined,
      Icons.sensors_rounded,
      'Devices',
      '/devices',
    ),
    _NavDestination(
      Icons.person_outline_rounded,
      Icons.person_rounded,
      'Profile',
      '/profile',
    ),
  ];

  void _navigate(BuildContext context, int index) {
    final route = _destinations[index].route;
    // Read the router's location directly. GoRouterState.of(context) can fail
    // when this shared scaffold's context is outside a RouteBase builder.
    final location = GoRouter.of(context).routeInformationProvider.value.uri;
    final currentPath = location.path;
    // Navigation destinations are top-level pages. Always leave nested farm
    // workspaces through go(), rather than popping a nested Navigator route.
    // This also ignores query parameters when deciding whether we're already
    // on the requested destination.
    if (index == 1) {
      // A new key forces WeatherScreen to reload the device location and
      // weather data whenever the Weather destination is tapped.
      context.go('/weather?refresh=${DateTime.now().microsecondsSinceEpoch}');
      return;
    }
    if (currentPath != route) context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final signedInUser = ref.watch(authControllerProvider).user;

    return LayoutBuilder(
      builder: (context, constraints) {
        final large = constraints.maxWidth >= 900;

        if (large) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              children: [
                _buildRail(context, ref, themeMode),
                Expanded(
                  child: Column(
                    children: [
                      _DesktopHeader(
                        title: title,
                        subtitle: subtitle,
                        actions: actions,
                        showBackButton: showBackButton,
                        onThemeToggle: () =>
                            ref.read(themeModeProvider.notifier).toggle(),
                        isDark: themeMode == ThemeMode.dark,
                      ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: floatingActionButton,
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: showBackButton
                ? IconButton(
                    tooltip: 'Back',
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else if (context.canPop()) {
                        context.pop();
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            actions: [
              // On narrow phones / resized browser windows, page-specific
              // actions can consume the entire toolbar. Keep the overflow menu
              // available and show optional actions only when they can fit.
              if (constraints.maxWidth >= 420) ...?actions,
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (value) async {
                  if (value == 'toggle_theme') {
                    ref.read(themeModeProvider.notifier).toggle();
                    return;
                  }
                  if (value != 'sign_out' || signedInUser == null) return;
                  final shouldSignOut = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Sign out?'),
                      content: const Text(
                        'Your saved farms and crop records will remain in your account.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  );
                  if (shouldSignOut != true || !context.mounted) return;
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'toggle_theme',
                    child: Row(
                      children: [
                        Icon(
                          themeMode == ThemeMode.dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          themeMode == ThemeMode.dark
                              ? 'Switch to light mode'
                              : 'Switch to dark mode',
                        ),
                      ],
                    ),
                  ),
                  if (signedInUser != null)
                    const PopupMenuItem<String>(
                      value: 'sign_out',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded),
                          SizedBox(width: 10),
                          Text('Sign out'),
                        ],
                      ),
                    ),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _navigate(context, index),
            destinations: _destinations
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }

  Widget _buildRail(BuildContext context, WidgetRef ref, ThemeMode themeMode) {
    final user = ref.watch(authControllerProvider).user;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface
            .withValues(alpha: themeMode == ThemeMode.dark ? 0.8 : 0.9),
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: NavigationRail(
        extended: true,
        minExtendedWidth: 248,
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _navigate(context, index),
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
          child: SizedBox(
            width: 220,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.eco_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ArecaSmart',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Smart farm workspace',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        destinations: _destinations
            .map(
              (item) => NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              ),
            )
            .toList(),
        trailingAtBottom: true,
        trailing: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: Text(
                        _initials(user.name.isEmpty ? 'Farmer' : user.name),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      user.name.isEmpty ? 'Farmer' : user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Signed in'),
                  ),
                ),
              Divider(
                indent: 12,
                endIndent: 12,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 220,
                  child: ListTile(
                    leading: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    title: Text(
                      themeMode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
                    ),
                    onTap: () => ref.read(themeModeProvider.notifier).toggle(),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign out'),
                  onTap: user == null
                      ? null
                      : () =>
                            ref.read(authControllerProvider.notifier).logout(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _DesktopHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback onThemeToggle;
  final bool isDark;
  final bool showBackButton;

  const _DesktopHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.onThemeToggle,
    required this.isDark,
    required this.showBackButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface
            .withValues(alpha: isDark ? 0.8 : 0.9),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          if (showBackButton)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Back',
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else if (context.canPop()) {
                    context.pop();
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: onThemeToggle,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          ...?actions,
        ],
      ),
    );
  }
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const _NavDestination(this.icon, this.selectedIcon, this.label, this.route);
}
