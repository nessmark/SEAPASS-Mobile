import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_exception.dart';
import '../services/passenger_data_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/seapass_logo.dart';
import 'passenger_home_screen.dart';

/// Two-step registration screen.
///
/// Step 1 – Fill in name, email, phone, and password, then request OTP.
/// Step 2 – Enter the 6-digit OTP sent to email to complete registration.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  // ─── Step tracking ────────────────────────────────────────────────────────
  int _step = 1; // 1 = details form, 2 = OTP verify

  // ─── Form controllers ─────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  // ─── UI state ─────────────────────────────────────────────────────────────
  final PassengerDataService _dataService = const PassengerDataService();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';

  // ─── OTP resend timer ─────────────────────────────────────────────────────
  Timer? _resendTimer;
  int _resendCountdown = 0;

  late final AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    for (final c in _otpControllers) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    _resendTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  // ─── Step 1: Send OTP ─────────────────────────────────────────────────────

  Future<void> _requestOtp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      final msg = await _dataService.sendOtp(email: email);
      if (!mounted) return;
      setState(() {
        _step = 2;
        _successMessage = msg;
      });
      _slideController.forward(from: 0);
      _startResendTimer();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'An unexpected error occurred: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Step 2: Verify OTP & Create Account ──────────────────────────────────

  Future<void> _verifyAndRegister() async {
    final otp = _otpControllers.map((c) => c.text.trim()).join();
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      await _dataService.verifyAndRegister(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
        otp: otp,
      );
      if (!mounted) return;
      _showSuccessDialog();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'An unexpected error occurred: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    final name = _nameController.text.trim();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppPalette.mintGreen, size: 28),
            SizedBox(width: 8),
            Text('Account Verified!'),
          ],
        ),
        content: Text(
          name.isNotEmpty
              ? 'Welcome to SeaPass, $name! Your account has been verified successfully. Let\'s find your Bangka for your trip.'
              : 'Your SeaPass account has been verified successfully. Welcome aboard!',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushNamedAndRemoveUntil(
                PassengerHomeScreen.routeName,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.mintGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('EXPLORE TRIP SCHEDULES'),
          ),
        ],
      ),
    );
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  void _goBackToStep1() {
    setState(() {
      _step = 1;
      _errorMessage = '';
      _successMessage = '';
      for (final c in _otpControllers) { c.clear(); }
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppPalette.darkText, size: 20),
          onPressed: () =>
              _step == 2 ? _goBackToStep1() : Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Header ─────────────────────────────────────────
              const SeaPassLogo(size: 64),
              const SizedBox(height: 12),
              const Text(
                'Create Your Account',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.darkText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _step == 1
                    ? 'Fill in your details to get started'
                    : 'Enter the 6-digit code sent to your email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),

              // ── Step indicator ───────────────────────────────────────────
              _buildStepIndicator(),
              const SizedBox(height: 24),

              // ── Error / success banners ──────────────────────────────────
              if (_errorMessage.isNotEmpty) ...[
                _buildBanner(
                    message: _errorMessage,
                    isError: true),
                const SizedBox(height: 12),
              ],
              if (_successMessage.isNotEmpty && _step == 2) ...[
                _buildBanner(
                    message: _successMessage,
                    isError: false),
                const SizedBox(height: 12),
              ],

              // ── Step content ─────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _step == 1
                    ? _buildDetailsForm()
                    : _buildOtpForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step indicator ───────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stepDot(1, 'Details'),
        _stepLine(),
        _stepDot(2, 'Verify'),
      ],
    );
  }

  Widget _stepDot(int step, String label) {
    final active = _step >= step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppPalette.mintGreen : Colors.grey.shade300,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: active ? Colors.white : Colors.grey.shade500,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? AppPalette.mintGreen : Colors.grey.shade400,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _stepLine() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 6, right: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 60,
        height: 2,
        color: _step >= 2 ? AppPalette.mintGreen : Colors.grey.shade300,
      ),
    );
  }

  // ─── Step 1: Details form ─────────────────────────────────────────────────

  Widget _buildDetailsForm() {
    return Column(
      key: const ValueKey('step1'),
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          prefixIcon: Icons.person_outline_rounded,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppPalette.subtleGrey,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _confirmController,
          label: 'Confirm Password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirm,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppPalette.subtleGrey,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
          onSubmitted: (_) => _requestOtp(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.mintGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppPalette.mintGreen.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'SEND VERIFICATION CODE',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.6),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account? ',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                'Log In',
                style: TextStyle(
                  color: AppPalette.mintGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Step 2: OTP form ─────────────────────────────────────────────────────

  Widget _buildOtpForm() {
    return Column(
      key: const ValueKey('step2'),
      children: [
        // Destination hint
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppPalette.mintGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppPalette.mintGreen.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline_rounded,
                  color: AppPalette.mintGreen, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _emailController.text.trim(),
                  style: const TextStyle(
                    color: AppPalette.darkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // 6 OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _buildOtpBox(i)),
        ),
        const SizedBox(height: 28),

        // Verify button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyAndRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.mintGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppPalette.mintGreen.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'VERIFY & CREATE ACCOUNT',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.6),
                  ),
          ),
        ),
        const SizedBox(height: 16),

        // Resend OTP
        if (_resendCountdown > 0)
          Text(
            'Resend code in ${_resendCountdown}s',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          )
        else
          GestureDetector(
            onTap: _isLoading ? null : _requestOtp,
            child: const Text(
              'Resend verification code',
              style: TextStyle(
                color: AppPalette.mintGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _goBackToStep1,
          child: Text(
            '← Edit my details',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
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
            borderSide:
                const BorderSide(color: AppPalette.mintGreen, width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _otpFocusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _otpFocusNodes[index - 1].requestFocus();
          }
          // Clear error when typing
          if (_errorMessage.isNotEmpty) {
            setState(() => _errorMessage = '');
          }
        },
      ),
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction:
          onSubmitted != null ? TextInputAction.done : TextInputAction.next,
      onSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 15, color: AppPalette.darkText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: 14, color: AppPalette.subtleGrey),
        prefixIcon: Icon(prefixIcon, size: 20, color: AppPalette.subtleGrey),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppPalette.mintGreen, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildBanner({required String message, required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? Colors.red.shade200 : Colors.green.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? Colors.red.shade600 : Colors.green.shade600,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red.shade700 : Colors.green.shade700,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
