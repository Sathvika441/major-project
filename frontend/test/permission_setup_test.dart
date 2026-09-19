import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/storage/local_storage_service.dart';
import 'package:major_proj_1/services/permissions/permission_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('permission flow flag starts false and can be completed', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await LocalStorageService.init();
    final service = PermissionService(storage);

    expect(service.hasCompletedPermissionFlow(), isFalse);
    await service.markFlowCompleted();
    expect(service.hasCompletedPermissionFlow(), isTrue);
  });
}
