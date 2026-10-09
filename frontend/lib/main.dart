import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_mode_controller.dart';
import 'core/services/location_master_service.dart';
import 'core/storage/local_storage_service.dart';
import 'core/utils/app_logger.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppLogger.info('Initializing ArecaSmart application...', tag: 'Main');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  AppLogger.info('Firebase initialized successfully', tag: 'Main');

  final localStorageService = await LocalStorageService.init();
  final locationMasterService = LocationMasterService();

  await locationMasterService.load();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorageService),
        locationMasterServiceProvider.overrideWithValue(locationMasterService),
      ],
      child: const ArecaSmartApp(),
    ),
  );
}

class ArecaSmartApp extends ConsumerWidget {
  const ArecaSmartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'ArecaSmart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [const _AmbientBackground(), ?child],
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final glow = dark ? AppColors.primaryLight : AppColors.primary;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: base),
          Positioned(
            top: -360,
            right: -260,
            child: _AmbientGlow(
              color: glow.withValues(alpha: dark ? 0.2 : 0.08),
            ),
          ),
          Positioned(
            bottom: -420,
            left: -300,
            child: _AmbientGlow(
              color: AppColors.accentTeal.withValues(alpha: dark ? 0.1 : 0.05),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  final Color color;

  const _AmbientGlow({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 820,
      height: 820,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
