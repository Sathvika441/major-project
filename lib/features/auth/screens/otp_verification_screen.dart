import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../core/utils/app_logger.dart';
import '../../../widgets/app_button.dart';
import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _resendTimer;
  Timer? _tickTimer;
  int _resendSeconds = 60;
  bool _verifying = false;
  bool _resentOnce = false;
  String? _lastDisplayedOtp;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authControllerProvider);
      AppLogger.info(
        '[QA NOTICE] OTP for ${authState.pendingOtpPhone} is logged. '
        'Check the debug console for the "MOCK ENCRYPTED SMS" line.',
        tag: 'OtpScreen',
      );
      _showQaToast(authState);
    });
  }

  void _showQaToast(AuthState authState) {
    final code = _extractLoggedOtpFromLog();
    if (code == null) return;
    if (_lastDisplayedOtp == code) return;
    _lastDisplayedOtp = code;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF14532D),
        duration: const Duration(seconds: 10),
        content: Row(
          children: [
            const Icon(Icons.sms, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '[QA] Mock SMS OTP for ${authState.pendingOtpPhone}: $code',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractLoggedOtpFromLog() {
    return null;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendSeconds = 60;
    _resendTimer?.cancel();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    final ctrl = ref.read(authControllerProvider.notifier);
    ctrl.clearMessages();
    final canResend = ctrl.canResendOtp();
    if (canResend != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please wait ${canResend.inSeconds}s before resending')),
      );
      return;
    }
    if (ctrl.isOtpLocked()) {
      final lock = ctrl.remainingLockout();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Too many failed attempts. Try again in ${lock?.inMinutes ?? 5} min.',
          ),
        ),
      );
      return;
    }
    final code = await ctrl.sendLoginOtp();
    if (code != null && mounted) {
      _resentOnce = true;
      _startResendCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF14532D),
          duration: const Duration(seconds: 10),
          content: Text('[QA] New OTP sent: $code'),
        ),
      );
    }
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
    ref.read(authControllerProvider.notifier).clearMessages();
    final ok = await ref
        .read(authControllerProvider.notifier)
        .verifyOtpAndLogin(code);
    if (!mounted) return;
    setState(() => _verifying = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone verified successfully.'),
          backgroundColor: Color(0xFF14532D),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final phone = authState.pendingOtpPhone ?? authState.user?.phone ?? 'your phone';
    final forPurpose = authState.pendingOtpFor == 'signup' ? 'sign up' : 'log in';
    final locked = authState.status == AuthStatus.otpVerificationPending &&
        ref.read(authControllerProvider.notifier).isOtpLocked();
    final lockRemaining =
        ref.read(authControllerProvider.notifier).remainingLockout();

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
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_user_rounded,
                      size: 44,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Enter the 6-digit code',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayLarge?.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a verification code via encrypted SMS to $phone to complete your $forPurpose.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),

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

                if (locked && lockRemaining != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: Color(0xFFC2410C)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Too many failed attempts. Please try again in ${lockRemaining.inMinutes}m ${lockRemaining.inSeconds.remainder(60)}s.',
                            style: const TextStyle(
                              color: Color(0xFF9A3412),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                if (authState.successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6EE7B7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF059669)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            authState.successMessage!,
                            style: const TextStyle(
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                Center(
                  child: Pinput(
                    controller: _pinController,
                    focusNode: _focusNode,
                    length: 6,
                    keyboardType: TextInputType.number,
                    onCompleted: (_) => _submitOtp(),
                    pinAnimationType: PinAnimationType.fade,
                    defaultPinTheme: PinTheme(
                      width: 48,
                      height: 56,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 48,
                      height: 56,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    errorPinTheme: PinTheme(
                      width: 48,
                      height: 56,
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDC2626), width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    showCursor: true,
                  ),
                ),
                const SizedBox(height: 28),

                AppButton(
                  text: _verifying ? 'Verifying...' : 'Verify & Continue',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: _verifying,
                  onPressed: _submitOtp,
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Didn't receive the code?  "),
                    if (_resendSeconds > 0)
                      Text(
                        'Resend in ${_resendSeconds}s',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _resendOtp,
                        child: Text(
                          _resentOnce ? 'Resend code again' : 'Resend code',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'OTP expires in 15 minutes. Maximum 5 attempts before 5-minute lockout.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
