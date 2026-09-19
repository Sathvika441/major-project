import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../../widgets/app_button.dart';
import '../controllers/auth_controller.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _tickTimer;
  int _resendSeconds = 2;
  bool _verifying = false;
  bool _resentOnce = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _tickTimer?.cancel();
    setState(() => _resendSeconds = 2);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        setState(() => _resendSeconds = 0);
        timer.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resendOtp() async {
    final ctrl = ref.read(authControllerProvider.notifier);
    ctrl.clearMessages();
    final lock = ctrl.remainingLockout();
    if (lock != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Too many failed attempts. Try again in ${lock.inMinutes} min.')),
      );
      return;
    }
    final cooldown = ctrl.canResendOtp();
    if (cooldown != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait ${cooldown.inSeconds}s before resending.')),
      );
      return;
    }
    final code = await ctrl.sendLoginOtp();
    if (!mounted || code == null) return;
    _pinController.clear();
    _resentOnce = true;
    _startResendCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('[QA] New OTP sent: $code'),
        duration: const Duration(seconds: 10),
      ),
    );
  }

  Future<void> _submitOtp() async {
    if (_verifying) return;
    final code = _pinController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit OTP.')),
      );
      return;
    }

    setState(() => _verifying = true);
    final ok = await ref.read(authControllerProvider.notifier).verifyOtpAndLogin(code);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (!ok) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Phone verified successfully.'),
        backgroundColor: Color(0xFF14532D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final phone = authState.pendingOtpPhone ?? authState.user?.phone ?? 'your phone';
    final purpose = authState.pendingOtpFor == 'signup' ? 'sign up' : 'log in';
    final lock = ref.read(authControllerProvider.notifier).remainingLockout();

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.verified_user_rounded, size: 44, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Enter the 6-digit code', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('We sent a verification code to $phone to complete your $purpose.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (authState.errorMessage != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(authState.errorMessage!),
                    ),
                  ),
                if (lock != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: Text('Locked for ${lock.inMinutes}m ${lock.inSeconds.remainder(60)}s'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: Pinput(
                    controller: _pinController,
                    focusNode: _focusNode,
                    length: 6,
                    keyboardType: TextInputType.number,
                    onCompleted: (_) => _submitOtp(),
                    defaultPinTheme: PinTheme(
                      width: 48,
                      height: 56,
                      textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: _verifying ? 'Verifying...' : 'Verify & Continue',
                  icon: Icons.check_circle_outline,
                  isLoading: _verifying,
                  onPressed: _submitOtp,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Didn't receive the code?  "),
                    if (_resendSeconds > 0)
                      Text('Resend in ${_resendSeconds}s', style: const TextStyle(fontWeight: FontWeight.w600))
                    else
                      GestureDetector(
                        onTap: _resendOtp,
                        child: Text(
                          _resentOnce ? 'Resend code again' : 'Resend code',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('OTP expires in 15 minutes. Maximum 5 attempts before a 5-minute lockout.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

