class AuthValidators {
  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  static final RegExp _phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');

  /// Validates email address format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    final trimmed = value.trim();
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address (e.g. farmer@areca.org).';
    }
    return null;
  }

  /// Validates password strength (minimum 8 characters, at least one letter and one number)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!value.contains(RegExp(r'[A-Za-z]')) || !value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain both letters and numbers.';
    }
    return null;
  }

  /// Validates matching confirm password
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != password) {
      return 'Passwords do not match.';
    }
    return null;
  }

  /// Validates user full name
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required.';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters.';
    }
    return null;
  }

  /// Validates phone number
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    final trimmed = value.trim().replaceAll(' ', '').replaceAll('-', '');
    if (!_phoneRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid phone number.';
    }
    return null;
  }

  /// Validates Terms and Conditions acceptance
  static String? validateTerms(bool? value) {
    if (value != true) {
      return 'You must accept the Terms and Conditions to register.';
    }
    return null;
  }
}
