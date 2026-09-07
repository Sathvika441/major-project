import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/validators/auth_validators.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _termsError;

  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitSignup() async {
    setState(() {
      _termsError = AuthValidators.validateTerms(_acceptedTerms);
    });

    if (!_formKey.currentState!.validate() || _termsError != null) {
      return;
    }

    FocusScope.of(context).unfocus();
    final authController = ref.read(authControllerProvider.notifier);
    authController.clearMessages();

    final success = await authController.signUp(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join ArecaSmart',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 6),
              Text(
                'Register your profile to manage farms, plots, IoT sensors and disease AI diagnostic tools.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Error Banner
              if (authState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Signup Form Card
              AppCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'Ramesh Gowda',
                        prefixIcon: Icons.person_outline_rounded,
                        validator: AuthValidators.validateName,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _emailController,
                        label: 'Email Address',
                        hint: 'ramesh@farm.org',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: AuthValidators.validateEmail,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: '+91 9876543210',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: AuthValidators.validatePhone,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _passwordController,
                        label: 'Password',
                        isPassword: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: AuthValidators.validatePassword,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        isPassword: true,
                        prefixIcon: Icons.lock_clock_outlined,
                        validator: (val) =>
                            AuthValidators.validateConfirmPassword(
                              val,
                              _passwordController.text,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Terms and Conditions Checkbox
                      InkWell(
                        onTap: () {
                          setState(() {
                            _acceptedTerms = !_acceptedTerms;
                            _termsError = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _acceptedTerms,
                                  activeColor: theme.primaryColor,
                                  onChanged: (val) {
                                    setState(() {
                                      _acceptedTerms = val ?? false;
                                      _termsError = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                      fontSize: 13,
                                    ),
                                    children: [
                                      const TextSpan(text: 'I agree to the '),
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' for agricultural data usage.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_termsError != null) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 34),
                          child: Text(
                            _termsError!,
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Submit Button
                      AppButton(
                        text: 'Register Account',
                        isLoading: authState.status == AuthStatus.loading,
                        onPressed: _submitSignup,
                        icon: Icons.person_add_alt_1_rounded,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Return to Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already registered?',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      ref.read(authControllerProvider.notifier).clearMessages();
                      context.pop();
                    },
                    child: Text(
                      'Sign In',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
