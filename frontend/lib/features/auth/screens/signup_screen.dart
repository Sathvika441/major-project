import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/theme_mode_controller.dart';
import '../../../core/validators/auth_validators.dart';
import '../../../widgets/app_button.dart';
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
    setState(() => _termsError = AuthValidators.validateTerms(_acceptedTerms));
    if (!_formKey.currentState!.validate() || _termsError != null) return;

    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    controller.clearMessages();

    final success = await controller.signUp(
      name: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );

    if (!mounted || !success) return;

    if (ref.read(authControllerProvider).status ==
        AuthStatus.otpVerificationPending) {
      context.go('/otp-verification');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        actions: [
          IconButton(
            tooltip: themeMode == ThemeMode.dark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            icon: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/images (2).jpeg', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xD9000805), Color(0xA6000805), Color(0xD9000805)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      size: 34,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Join ArecaSmart',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your farmer workspace to manage farms, sensors and crop health insights.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  if (authState.errorMessage != null) ...[
                    _MessageBanner(
                      icon: Icons.error_outline_rounded,
                      text: authState.errorMessage!,
                      error: true,
                    ),
                    const SizedBox(height: 14),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppTextField(
                              controller: _nameController,
                              label: 'Full name',
                              hint: 'Your name',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: AuthValidators.validateName,
                            ),
                            const SizedBox(height: 15),
                            AppTextField(
                              controller: _emailController,
                              label: 'Email address',
                              hint: 'farmer@example.com',
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: Icons.email_outlined,
                              validator: AuthValidators.validateEmail,
                            ),
                            const SizedBox(height: 15),
                            AppTextField(
                              controller: _phoneController,
                              label: 'Phone number',
                              hint: '+91 9876543210',
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_outlined,
                              validator: AuthValidators.validatePhone,
                            ),
                            const SizedBox(height: 15),
                            AppTextField(
                              controller: _passwordController,
                              label: 'Password',
                              isPassword: true,
                              prefixIcon: Icons.lock_outline_rounded,
                              validator: AuthValidators.validatePassword,
                            ),
                            const SizedBox(height: 15),
                            AppTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm password',
                              isPassword: true,
                              prefixIcon: Icons.lock_clock_outlined,
                              validator: (value) =>
                                  AuthValidators.validateConfirmPassword(
                                value,
                                _passwordController.text,
                              ),
                            ),
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: () => setState(() {
                                _acceptedTerms = !_acceptedTerms;
                                _termsError = null;
                              }),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _acceptedTerms,
                                    onChanged: (value) => setState(() {
                                      _acceptedTerms = value ?? false;
                                      _termsError = null;
                                    }),
                                  ),
                                  const SizedBox(width: 4),
                                  const Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 12),
                                      child: Text(
                                        'I agree to the Terms of Service and Privacy Policy for agricultural data usage.',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_termsError != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Text(
                                  _termsError!,
                                  style: TextStyle(
                                    color: scheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 18),
                            AppButton(
                              text: 'Create account',
                              isLoading:
                                  authState.status == AuthStatus.loading,
                              onPressed: _submitSignup,
                              icon: Icons.arrow_forward_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: () {
                          ref
                              .read(authControllerProvider.notifier)
                              .clearMessages();
                          context.go('/login');
                        },
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool error;

  const _MessageBanner({
    required this.icon,
    required this.text,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: error ? scheme.error : scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
