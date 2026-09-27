import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_storage_service.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(localStorageServiceProvider));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  final LocalStorageService _storage;

  ThemeModeController(this._storage) : super(ThemeMode.light) {
    _restore();
  }

  Future<void> _restore() async {
    final saved = _storage.raw.getString(LocalStorageKeys.themeMode);
    if (saved == ThemeMode.dark.name) {
      state = ThemeMode.dark;
    } else if (saved == ThemeMode.light.name) {
      state = ThemeMode.light;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.raw.setString(LocalStorageKeys.themeMode, mode.name);
  }

  Future<void> toggle() async {
    await setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
