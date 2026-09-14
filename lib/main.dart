import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme/app_theme.dart';
import 'core/services/location_master_service.dart';
import 'core/storage/local_storage_service.dart';
import 'core/utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('Initializing ArecaSmart application...', tag: 'Main');

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
    return MaterialApp.router(
      title: 'ArecaSmart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
