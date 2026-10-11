import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/validators/auth_validators.dart';

void main() {
  test('accepts valid Karnataka survey numbers', () {
    for (final value in ['123', '12/3', '12/3A', '12/3/4']) {
      expect(AuthValidators.validateSurveyNumber(value), isNull, reason: value);
    }
  });

  test('rejects invalid survey numbers', () {
    for (final value in ['abc', '12//3', '123456789']) {
      expect(
        AuthValidators.validateSurveyNumber(value),
        isNotNull,
        reason: value,
      );
    }
  });
}
