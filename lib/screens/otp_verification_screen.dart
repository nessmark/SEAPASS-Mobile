import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/seapass_logo.dart';
import 'passenger_home_screen.dart';

/// Arguments payload passed from [SignupScreen] to [OtpVerificationScreen].
class OtpVerificationArguments {
  final String name;
  final String email;
  final String phone;
  final String password;
  final String confirmPassword;

  const OtpVerificationArguments({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.confirmPassword,
  });
}

/// 6-digit OTP verification screen with 60-second resend cooldown timer.
class OtpVerificationScreen extends StatefulWidget {
  static const String routeName = '/otp-verification';

  final OtpVerificationArguments? arguments;

  const OtpVerificationScreen({
    super.key,
    this.arguments,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _isLoading = false;
  bool _isResending = false;
  String _errorMessage = '';

  OtpVerificationArguments? _resolvedArgs;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(6, (_) => TextEditingController());
    _focusNodes = List.generate(6, (_) => FocusNode());
    _startCountdownTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolvedArgs == null) {
      if (widget.arguments != null) {
        _resolvedArgs = widget.arguments;
      } else {
        final modalArgs = ModalRoute.of(context)?.settings.arguments;
        if (modalArgs is OtpVerificationArguments) {
          _resolvedArgs = modalArgs;
        }
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _currentOtp =>
      _controllers.map((c) => c.text.trim()).join();

  Future<void> _resendOtp() async {
    final email = _resolvedArgs?.email ?? '';
    if (email.isEmpty) {
      _showErrorSnackBar('No email address available to resend OTP.');
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    try {
      final msg = await AuthService.sendOtp(email: email);
      if (!mounted) return;

      _startCountdownTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: AppPalette.mintGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) {
        final error = 'Failed to resend code: $e';
        setState(() => _errorMessage = error);
        _showErrorSnackBar(error);
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _verifyAndCompleteRegistration() async {
    final args = _resolvedArgs;
    if (args == null) {
      _showErrorSnackBar('Missing registration details. Please go back and retry.');
      return;
    }

    final otp = _currentOtp;
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the OTP code.');
      _showErrorSnackBar('Please enter all 6 digits of the OTP code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await AuthService.verifyAndRegister(
        name: args.name,
        email: args.email,
        phone: args.phone,
        password: args.password,
        passwordConfirmation: args.confirmPassword,
        otp: otp,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Welcome, ${args.name}! Registration complete.'),
              ),
            ],
          ),
          backgroundColor: AppPalette.mintGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Navigate to HomeScreen and clear all prior auth routes
      Navigator.of(context).pushNamedAndRemoveUntil(
        PassengerHomeScreen.routeName,
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      if (mounted) {
        final error = 'Registration failed: $e';
        setState(() => _errorMessage = error);
        _showErrorSnackBar(error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleOtpInput(String val, int index) {
    // Handle multi-character paste
    if (val.length > 1) {
      final digits = val.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final targetIndex = digits.length >= 6 ? 5 : digits.length;
      _focusNodes[targetIndex].requestFocus();
      if (_currentOtp.length == 6) {
        _verifyAndCompleteRegistration();
      }
      return;
    }

    if (val.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (val.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_errorMessage.isNotEmpty) {
      setState(() => _errorMessage = '');
    }

    // Auto trigger submission when 6th digit entered
    if (_currentOtp.length == 6 && index == 5) {
      _verifyAndCompleteRegistration();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _resolvedArgs?.email ?? 'your email';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppPalette.darkText,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Top Brand & Icon Header ──
              const Center(child: SeaPassLogo(size: 60)),
              const SizedBox(height: 20),

              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppPalette.mintGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppPalette.mintGreen,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.darkText,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Please enter the 6-digit verification code sent to:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),

              // Highlighted email badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppPalette.mintGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppPalette.mintGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 15,
                      color: AppPalette.mintGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.darkText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Inline error banner if any ──
              if (_errorMessage.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── 6-digit PIN Box Grid ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),
              const SizedBox(height: 32),

              // ── Verify & Complete Registration Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _isLoading ? null : _verifyAndCompleteRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.mintGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppPalette.mintGreen.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'VERIFY & COMPLETE REGISTRATION',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Resend OTP Countdown & Button ──
              if (_secondsRemaining > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Resend code in ${_secondsRemaining}s',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Didn\'t receive the code? ',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: (_isLoading || _isResending) ? null : _resendOtp,
                      child: _isResending
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppPalette.mintGreen,
                              ),
                            )
                          : const Text(
                              'Resend OTP',
                              style: TextStyle(
                                color: AppPalette.mintGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),

              // ── Edit Details Link ──
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 16, color: AppPalette.subtleGrey),
                label: const Text(
                  'Edit Registration Details',
                  style: TextStyle(
                    color: AppPalette.subtleGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppPalette.darkText,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppPalette.mintGreen,
              width: 2,
            ),
          ),
        ),
        onChanged: (val) => _handleOtpInput(val, index),
      ),
    );
  }
}
