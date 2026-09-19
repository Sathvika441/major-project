import 'package:flutter_test/flutter_test.dart';
import 'package:major_proj_1/core/validators/auth_validators.dart';

void main() {
  group('AuthValidators Tests', () {
    test('validateEmail returns error for empty or invalid emails', () {
      expect(AuthValidators.validateEmail(''), isNotNull);
      expect(AuthValidators.validateEmail('   '), isNotNull);
      expect(AuthValidators.validateEmail('invalid-email'), isNotNull);
      expect(AuthValidators.validateEmail('farmer@'), isNotNull);
      expect(AuthValidators.validateEmail('farmer@areca.org'), isNull);
    });

    test('validatePassword enforces length and complexity', () {
      expect(AuthValidators.validatePassword('short'), isNotNull);
      expect(AuthValidators.validatePassword('onlyletters'), isNotNull);
      expect(AuthValidators.validatePassword('12345678'), isNotNull);
      expect(AuthValidators.validatePassword('Password123'), isNull);
    });

    test('validateConfirmPassword checks match', () {
      expect(AuthValidators.validateConfirmPassword('Pass123', 'Pass456'), isNotNull);
      expect(AuthValidators.validateConfirmPassword('Pass123', 'Pass123'), isNull);
    });

    test('validateName checks required non-empty string', () {
      expect(AuthValidators.validateName(''), isNotNull);
      expect(AuthValidators.validateName('A'), isNotNull);
      expect(AuthValidators.validateName('Ramesh Gowda'), isNull);
    });

    test('validatePhone checks numeric phone format', () {
      expect(AuthValidators.validatePhone('abc'), isNotNull);
      expect(AuthValidators.validatePhone('123'), isNotNull);
      expect(AuthValidators.validatePhone('+919876543210'), isNull);
    });

    test('validateTerms requires true', () {
      expect(AuthValidators.validateTerms(false), isNotNull);
      expect(AuthValidators.validateTerms(null), isNotNull);
      expect(AuthValidators.validateTerms(true), isNull);
    });
  });
}
