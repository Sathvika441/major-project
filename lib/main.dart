import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme/app_theme.dart';
import 'core/storage/local_storage_service.dart';
import 'core/utils/app_logger.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// import 'features/auth/controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('Initializing ArecaSmart application...', tag: 'Main');

  // Initialize Local Storage Service
  final localStorageService = await LocalStorageService.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorageService),
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

    return MaterialApp.router(
      title: 'ArecaSmart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
