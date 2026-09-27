import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/theme_mode_controller.dart';
import '../../../core/validators/auth_validators.dart';
import '../../../widgets/app_button.dart';
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

    if (ref.read(authControllerProvider).status ==
        AuthStatus.otpVerificationPending) {
      context.go('/otp-verification');
    }
  }

  Future<void> _submitGoogleLogin() async {
    FocusScope.of(context).unfocus();

    final success =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();

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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxWidth >= 900;

            if (split) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _BrandPanel(scheme: scheme),
                  ),
                  Expanded(
                    flex: 4,
                    child: _LoginForm(
                      formKey: _formKey,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      rememberMe: _rememberMe,
                      authState: authState,
                      themeMode: themeMode,
                      onRememberChanged: (value) =>
                          setState(() => _rememberMe = value),
                      onLogin: _submitLogin,
                      onGoogleLogin: _submitGoogleLogin,
                      onForgotPassword: () =>
                          context.push('/forgot-password'),
                      onSignUp: () => context.go('/signup'),
                      onThemeToggle: () =>
                          ref.read(themeModeProvider.notifier).toggle(),
                    ),
                  ),
                ],
              );
            }

            return Stack(
              children: [
                _LoginForm(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  rememberMe: _rememberMe,
                  authState: authState,
                  themeMode: themeMode,
                  compact: true,
                  onRememberChanged: (value) =>
                      setState(() => _rememberMe = value),
                  onLogin: _submitLogin,
                  onGoogleLogin: _submitGoogleLogin,
                  onForgotPassword: () =>
                      context.push('/forgot-password'),
                  onSignUp: () => context.go('/signup'),
                  onThemeToggle: () =>
                      ref.read(themeModeProvider.notifier).toggle(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final ColorScheme scheme;

  const _BrandPanel({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, 0.48)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -70,
            top: -70,
            child: _GlowCircle(
              size: 260,
              color: scheme.onPrimary.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: -90,
            bottom: -90,
            child: _GlowCircle(
              size: 300,
              color: scheme.onPrimary.withValues(alpha: 0.07),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: scheme.onPrimary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        color: scheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Text(
                      'ArecaSmart',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Smarter decisions\nfor healthier farms.',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Weather intelligence, irrigation recommendations and AI-powered arecanut disease detection in one farmer workspace.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.86),
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 30),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _FeaturePill(
                      icon: Icons.cloud_outlined,
                      label: 'Live weather',
                    ),
                    _FeaturePill(
                      icon: Icons.water_drop_outlined,
                      label: 'Irrigation insights',
                    ),
                    _FeaturePill(
                      icon: Icons.biotech_outlined,
                      label: 'AI crop health',
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'Built for practical, data-informed farm management.',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool rememberMe;
  final AuthState authState;
  final ThemeMode themeMode;
  final bool compact;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onLogin;
  final VoidCallback onGoogleLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignUp;
  final VoidCallback onThemeToggle;

  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.rememberMe,
    required this.authState,
    required this.themeMode,
    this.compact = false,
    required this.onRememberChanged,
    required this.onLogin,
    required this.onGoogleLogin,
    required this.onForgotPassword,
    required this.onSignUp,
    required this.onThemeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          compact ? 22 : 42,
          compact ? 30 : 44,
          compact ? 22 : 42,
          30,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: themeMode == ThemeMode.dark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onPressed: onThemeToggle,
                  icon: Icon(
                    themeMode == ThemeMode.dark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ),
              if (compact) ...[
                const SizedBox(height: 4),
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: scheme.primary,
                      size: 31,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue to your smart farm workspace.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              if (authState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scheme.error.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: scheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          authState.errorMessage!,
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: emailController,
                      label: 'Email address',
                      hint: 'farmer@example.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      validator: AuthValidators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: passwordController,
                      label: 'Password',
                      isPassword: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: AuthValidators.validatePassword,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Checkbox(
                          value: rememberMe,
                          onChanged: (value) =>
                              onRememberChanged(value ?? true),
                        ),
                        const Text('Remember me'),
                        const Spacer(),
                        TextButton(
                          onPressed: onForgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      text: 'Sign in',
                      isLoading: authState.status == AuthStatus.loading,
                      onPressed: onLogin,
                      icon: Icons.arrow_forward_rounded,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      text: 'Continue with Google',
                      type: AppButtonType.outline,
                      isLoading: authState.status == AuthStatus.loading,
                      onPressed: onGoogleLogin,
                      icon: Icons.account_circle_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: scheme.outlineVariant,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'New to ArecaSmart?',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: scheme.outlineVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSignUp,
                  child: const Text('Create farmer account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
