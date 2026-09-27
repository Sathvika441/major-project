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

  AppLogger.info(
    'Initializing ArecaSmart application...',
    tag: 'Main',
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  AppLogger.info(
    'Firebase initialized successfully',
    tag: 'Main',
  );

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
    );
  }
}
