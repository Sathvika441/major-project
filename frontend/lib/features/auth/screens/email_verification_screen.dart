import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../controllers/auth_controller.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isResending = false;

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
    });

    await ref.read(authControllerProvider.notifier).resendVerificationEmail();

    if (mounted) {
      setState(() {
        _isResending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final email = authState.user?.email ?? 'your email address';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verify Your Email',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a verification link to:\n$email',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              if (authState.successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Text(
                    authState.successMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF14532D),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              AppCard(
                child: Column(
                  children: [
                    const Text(
                      'Please check your email inbox and click on the verification link to activate your ArecaSmart profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      text: 'Resend Verification Email',
                      isLoading: _isResending,
                      type: AppButtonType.outline,
                      icon: Icons.refresh_rounded,
                      onPressed: _resendEmail,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).logout();
                    context.go('/login');
                  },
                  child: const Text('Back to Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
