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
          backgroundColor: AppPalette.mintGreen,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Server Connection Settings',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Active Base URL: ${ApiConfig.baseUrl}',
                    style: const TextStyle(fontSize: 12, color: AppPalette.subtleGrey),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppPalette.mintGreen,
                        side: const BorderSide(color: AppPalette.mintGreen),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: ApiConfig.currentMode == ConnectionMode.usbAdb ? AppPalette.mintGreen.withValues(alpha: 0.15) : null,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: ApiConfig.currentMode == ConnectionMode.lanWifi ? AppPalette.mintGreen.withValues(alpha: 0.15) : null,
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
                              ElevatedButton(
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: ApiConfig.currentMode == ConnectionMode.androidEmulator ? AppPalette.mintGreen.withValues(alpha: 0.15) : null,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    tileColor: ApiConfig.currentMode == ConnectionMode.production ? AppPalette.mintGreen.withValues(alpha: 0.15) : null,
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
      backgroundColor: const Color(0xFFF2F4F7),
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
                              icon: const Icon(
                                Icons.settings_ethernet_rounded,
                                color: AppPalette.subtleGrey,
                              ),
                              onPressed: () => _showServerSettingsModal(context),
                            ),
                          ),

                          // Ferry logo (interactive on long-press)
                          GestureDetector(
                            onLongPress: () => _showServerSettingsModal(context),
                            child: const SeaPassLogo(size: 72),
                          ),
                          const SizedBox(height: 18),

                          // Title
                          const Text(
                            'SeaPass - San Jose Port\nPassenger',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.darkText,
                              height: 1.35,
                            ),
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
                                color: AppPalette.subtleGrey,
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
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _errorMessage,
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontSize: 12.5,
                                      height: 1.35,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      // Main Auto-Connect button
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppPalette.mintGreen,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
                                            textStyle: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold),
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          onPressed: _isLoading
                                              ? null
                                              : _handleAutoDetect,
                                          icon: const Icon(Icons.wifi_find_rounded, size: 18),
                                          label: const Text('Auto-Connect Server'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Manual Settings button
                                      IconButton.outlined(
                                        tooltip: 'Server Connection Settings',
                                        style: IconButton.styleFrom(
                                          side: BorderSide(color: Colors.grey.shade400),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => _showServerSettingsModal(context),
                                        icon: const Icon(Icons.settings, size: 18, color: AppPalette.darkText),
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
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
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
                                      'LOG IN',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Sign Up link
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SignupScreen()),
                            ),
                            child: const Text(
                              'Sign Up / Create Account',
                              style: TextStyle(
                                color: AppPalette.mintGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Bottom brand decoration (hidden when keyboard is open) ──
                  if (MediaQuery.of(context).viewInsets.bottom == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 36),
                      child: SeaPassLogo(
                        size: 88,
                        color: Colors.grey.shade400,
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
      style: const TextStyle(fontSize: 15, color: AppPalette.darkText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14, color: AppPalette.subtleGrey),
        prefixIcon:
            Icon(prefixIcon, size: 20, color: AppPalette.subtleGrey),
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
}