import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_exception.dart';
import '../services/api_service.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../services/token_storage_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/seapass_logo.dart';
import 'main_navigation_screen.dart';
import 'scanner_home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final PassengerDataService _dataService = const PassengerDataService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Restore saved server IP / Base URL on login screen render
    ApiService.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAutoDetect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    final detectedMode = await ApiConfig.autoDetectConnection();
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (detectedMode != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${detectedMode.label} (${ApiConfig.baseUrl})'),
          backgroundColor: AppPalette.teal500,
          duration: const Duration(seconds: 3),
        ),
      );
      if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
        _login();
      }
    } else {
      setState(() {
        _errorMessage = 'Could not auto-detect server on USB (127.0.0.1) or Wi-Fi (${ApiConfig.lanWifiHost}).\n'
            '• Start backend: php artisan serve --host=0.0.0.0 --port=8000\n'
            '• If using USB: run `adb reverse tcp:8000 tcp:8000` in terminal\n'
            '• If using Wi-Fi: check PC IP, Windows Firewall port 8000, and turn off phone mobile data.';
      });
    }
  }

  void _showServerSettingsModal(BuildContext context) {
    final ipController = TextEditingController(text: ApiConfig.lanWifiHost);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppPalette.radiusXl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Server Connection Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Active Base URL: ${ApiConfig.baseUrl}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.of(context).text3),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.of(context).tint,
                        foregroundColor: AppColors.of(context).onTint,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppPalette.radiusMd),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _handleAutoDetect();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Auto-Detect Active Connection'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppPalette.radiusSm)),
                    tileColor: ApiConfig.currentMode == ConnectionMode.usbAdb
                        ? AppColors.of(context).tint
                        : null,
                    leading: const Icon(Icons.usb_rounded),
                    title: const Text('USB Debugging (ADB Reverse)'),
                    subtitle: const Text('127.0.0.1:8000 (Requires adb reverse)'),
                    onTap: () async {
                      await ApiConfig.useUsbAdb();
                      setState(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppPalette.radiusSm)),
                    tileColor: ApiConfig.currentMode == ConnectionMode.lanWifi
                        ? AppColors.of(context).tint
                        : null,
                    leading: const Icon(Icons.wifi_rounded),
                    title: const Text('Wi-Fi (Auto-Connect Server)'),
                    subtitle: Text('Auto-scans & connects to PC (Target: http://${ApiConfig.lanWifiHost}:${ApiConfig.defaultPort})'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Type IP manually',
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Configure PC Wi-Fi IP'),
                            content: TextField(
                              controller: ipController,
                              decoration: const InputDecoration(
                                labelText: 'PC IPv4 Address',
                                hintText: '192.168.1.9',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () async {
                                  final ip = ipController.text.trim();
                                  if (ip.isNotEmpty) {
                                    await ApiConfig.useLanWifi(ip);
                                    setState(() {});
                                  }
                                  if (dCtx.mounted) Navigator.pop(dCtx);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                },
                                child: const Text('Save & Apply'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _handleAutoDetect();
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppPalette.radiusSm)),
                    tileColor: ApiConfig.currentMode == ConnectionMode.androidEmulator
                        ? AppColors.of(context).tint
                        : null,
                    leading: const Icon(Icons.phone_android_rounded),
                    title: const Text('Android Emulator (10.0.2.2)'),
                    subtitle: const Text('Host loopback alias for AVD emulators'),
                    onTap: () async {
                      await ApiConfig.useEmulator();
                      setState(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppPalette.radiusSm)),
                    tileColor: ApiConfig.currentMode == ConnectionMode.production
                        ? AppColors.of(context).tint
                        : null,
                    leading: const Icon(Icons.cloud_done_rounded),
                    title: const Text('Production Server'),
                    subtitle: const Text(ApiConfig.productionUrl),
                    onTap: () async {
                      await ApiConfig.useProduction();
                      setState(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final payload = await _dataService.login(email: email, password: password);
      if (!mounted) return;

      final role = payload['role']?.toString().toLowerCase() ?? PassengerSession.role;
      await TokenStorageService.saveUserRole(role);

      final token = await TokenStorageService.getToken();
      if (token != null && token.isNotEmpty) {
        ApiService.setAuthToken(token);
      }

      if (!mounted) return;

      if (role == 'scanner') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ScannerHomeScreen()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      MediaQuery.of(context).viewInsets.bottom)
                  .clamp(0.0, double.infinity),
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // ── Top section: logo + title + form ─────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Dev server quick-config button
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              tooltip: 'Server Connection Settings',
                              icon: Icon(
                                Icons.settings_ethernet_rounded,
                                color: AppColors.of(context).text3,
                              ),
                              onPressed: () => _showServerSettingsModal(context),
                            ),
                          ),

                          // Ferry logo (interactive on long-press)
                          GestureDetector(
                            onLongPress: () => _showServerSettingsModal(context),
                            child: const SeaPassLogo(size: 64),
                          ),
                          const SizedBox(height: 18),

                          // Title
                          Text(
                            'SeaPass - San Jose Port\nPassenger',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 36),

                          // Email field
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),

                          // Password field
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
                                color: AppColors.of(context).text3,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            onSubmitted: (_) => _login(),
                          ),

                          // Error message
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppPalette.danger.withValues(alpha: .12),
                                borderRadius:
                                    BorderRadius.circular(AppPalette.radiusMd),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _errorMessage,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppPalette.danger),
                                    textAlign: TextAlign.left,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      // Main Auto-Connect button
                                      Expanded(
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                            textStyle: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        AppPalette.radiusSm)),
                                          ),
                                          onPressed: _isLoading
                                              ? null
                                              : _handleAutoDetect,
                                          icon: const Icon(Icons.wifi_find_rounded, size: 18),
                                          label: const Text('Auto-Connect Server',
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Manual Settings button
                                      IconButton(
                                        tooltip: 'Server Connection Settings',
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              AppColors.of(context).surface,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppPalette.radiusSm)),
                                        ),
                                        onPressed: () => _showServerSettingsModal(context),
                                        icon: Icon(Icons.settings_rounded,
                                            size: 18,
                                            color: AppColors.of(context).text),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 22),

                          // LOG IN button
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _login,
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
                                      'Log in',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Sign Up link
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignupScreen()),
                            ),
                            child: const Text('Sign Up / Create Account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            Icon(prefixIcon, size: 20, color: AppColors.of(context).text3),
        suffixIcon: suffixIcon,
      ),
    );
  }
}