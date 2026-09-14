import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('phase flags default to incomplete', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();
    expect(storage.hasCompletedPhaseA(), isFalse);
    expect(storage.hasCompletedPhaseB(), isFalse);
    expect(storage.hasRequestedPermissions(), isFalse);
  });

  test('phase flags can be persisted independently', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();
    await storage.setCompletedPhaseA(true);
    expect(storage.hasCompletedPhaseA(), isTrue);
    expect(storage.hasCompletedPhaseB(), isFalse);
    await storage.setCompletedPhaseB(true);
    expect(storage.hasCompletedPhaseB(), isTrue);
  });
}
