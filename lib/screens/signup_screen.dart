import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/seapass_logo.dart';
import 'otp_verification_screen.dart';

/// Passenger sign-up screen with complete form validation and OTP trigger.
class SignupScreen extends StatefulWidget {
  static const String routeName = '/signup';

  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Form Controllers ──────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // ── Focus Nodes ───────────────────────────────────────────────────────────
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  // ── Input Validation ─────────────────────────────────────────────────────

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Please enter your full name.';
    }
    if (text.length < 2) {
      return 'Full name must be at least 2 characters.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Please enter your email address.';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(text)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Please enter your mobile phone number.';
    }
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Please enter a valid phone number (10-15 digits).';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Please enter a password.';
    }
    if (text.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Please confirm your password.';
    }
    if (text != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppPalette.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppPalette.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPalette.radiusMd)),
      ),
    );
  }

  // ── Form Submission & OTP Dispatch ───────────────────────────────────────

  Future<void> _handleSignup() async {
    // 1. Validate Form Fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 2. Call backend POST /api/passenger/send-otp
      final successMsg = await AuthService.sendOtp(email: email);
      if (!mounted) return;

      // 3. Show confirmation feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined, color: AppPalette.white),
              const SizedBox(width: 10),
              Expanded(child: Text(successMsg)),
            ],
          ),
          backgroundColor: AppPalette.teal500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPalette.radiusMd)),
        ),
      );

      // 4. Navigate to OTP verification screen with credentials payload
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            arguments: OtpVerificationArguments(
              name: name,
              email: email,
              phone: phone,
              password: password,
              confirmPassword: confirm,
            ),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
        _showErrorSnackBar(error.message);
      }
    } catch (e) {
      if (mounted) {
        final msg = 'Failed to request verification code: $e';
        setState(() => _errorMessage = msg);
        _showErrorSnackBar(msg);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      appBar: AppBar(
        backgroundColor: AppPalette.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.of(context).text,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Brand Header ──────────────────────────────────────
                const SeaPassLogo(size: 64),
                const SizedBox(height: 12),
                Text(
                  'Create Your Account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign up to book boat trips and manage your sea passes',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),

                // ── Error Banner if any ───────────────────────────────
                if (_errorMessage.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppPalette.danger.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppPalette.radiusSm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppPalette.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppPalette.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Form Input Fields ─────────────────────────────────
                _buildTextFormField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'e.g. Juan Dela Cruz',
                  prefixIcon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                ),
                const SizedBox(height: 14),

                _buildTextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  label: 'Email Address',
                  hint: 'juan@example.com',
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
                ),
                const SizedBox(height: 14),

                _buildTextFormField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  label: 'Phone Number',
                  hint: '09123456789',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: _validatePhone,
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: 14),

                _buildTextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  label: 'Password',
                  hint: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.of(context).text3,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  onFieldSubmitted: (_) => _confirmFocusNode.requestFocus(),
                ),
                const SizedBox(height: 14),

                _buildTextFormField(
                  controller: _confirmController,
                  focusNode: _confirmFocusNode,
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  validator: _validateConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.of(context).text3,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  onFieldSubmitted: (_) => _handleSignup(),
                ),
                const SizedBox(height: 28),

                // ── Sign Up / Register Button ─────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor:
                          AppPalette.teal500.withValues(alpha: 0.6),
                      disabledForegroundColor: AppPalette.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppPalette.radiusMd),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppPalette.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Create account',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              letterSpacing: 0,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Login Navigation Link ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Already have an account?',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Log In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    String? hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, size: 20, color: AppColors.of(context).text3),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
