import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/validators/auth_validators.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = 'Sathvika@gmail.com';
    _passwordController.text = 'Password123';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    controller.clearMessages();
    final success = await controller.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted || !success) return;
    if (ref.read(authControllerProvider).status == AuthStatus.otpVerificationPending) {
      context.go('/otp-verification');
    }
  }

  Future<void> _submitGoogleLogin() async {
    FocusScope.of(context).unfocus();
    final success = await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted || !success) return;
    if (ref.read(authControllerProvider).status == AuthStatus.otpVerificationPending) {
      context.go('/otp-verification');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.eco_rounded, size: 48, color: theme.primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Welcome Back', textAlign: TextAlign.center, style: theme.textTheme.displayLarge?.copyWith(fontSize: 28)),
                const SizedBox(height: 8),
                Text('Sign in to access Arecanut farm analytics and precision irrigation controls.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 32),
                if (authState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(authState.errorMessage!, style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 20),
                ],
                AppCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(controller: _emailController, label: 'Email Address', hint: 'farmer@areca.org', keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_outlined, validator: AuthValidators.validateEmail),
                        const SizedBox(height: 20),
                        AppTextField(controller: _passwordController, label: 'Password', isPassword: true, prefixIcon: Icons.lock_outline_rounded, validator: AuthValidators.validatePassword),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(width: 24, height: 24, child: Checkbox(value: _rememberMe, onChanged: (value) => setState(() => _rememberMe = value ?? true))),
                                const SizedBox(width: 8),
                                const Text('Remember me'),
                              ],
                            ),
                            TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?')),
                          ],
                        ),
                        const SizedBox(height: 24),
                        AppButton(text: 'Sign In', isLoading: authState.status == AuthStatus.loading, onPressed: _submitLogin, icon: Icons.login_rounded),
                        const SizedBox(height: 12),
                        AppButton(text: 'Continue with Google', type: AppButtonType.outline, isLoading: authState.status == AuthStatus.loading, onPressed: _submitGoogleLogin, icon: Icons.account_circle_outlined),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?", style: theme.textTheme.bodyMedium),
                    TextButton(onPressed: () => context.go('/signup'), child: const Text('Sign Up')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
