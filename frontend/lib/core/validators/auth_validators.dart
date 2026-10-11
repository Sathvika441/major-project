class AuthValidators {
  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  static final RegExp _phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');
  static final RegExp _surveyNumberRegExp = RegExp(
    r'^[0-9]+(?:/[0-9]+)*[A-Za-z]?$',
  );

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

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!value.contains(RegExp(r'[A-Za-z]')) ||
        !value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain both letters and numbers.';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != password) {
      return 'Passwords do not match.';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required.';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters.';
    }
    return null;
  }

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

  static String? validateSurveyNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Land survey number is required.';
    }
    final trimmed = value.trim();
    if (trimmed.length > 8) {
      return 'Survey number is too long.';
    }
    if (!_surveyNumberRegExp.hasMatch(trimmed)) {
      return 'Enter a valid Karnataka survey number (e.g. 12/3A).';
    }
    return null;
  }

  static String? validateTerms(bool? value) {
    if (value != true) {
      return 'You must accept the Terms and Conditions to register.';
    }
    return null;
  }
}
