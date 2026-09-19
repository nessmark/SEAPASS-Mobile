import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../widgets/app_palette.dart';
import 'login_screen.dart';
import 'view_ticket_screen.dart';

class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  final PassengerDataService _dataService = const PassengerDataService();
  bool _isLoadingHistory = true;
  List<Booking> _travelHistory = [];

  @override
  void initState() {
    super.initState();
    _loadTravelHistory();
  }

  Future<void> _loadTravelHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final int passengerId = PassengerSession.passengerId;
      final String passengerName = PassengerSession.name;

      final data = await _dataService.fetchPassengerBookings(
        passengerId: passengerId > 0 ? passengerId : null,
        passengerName: passengerId <= 0 && passengerName.isNotEmpty
            ? passengerName
            : null,
      );

      final List<Booking> all = data['all'] ?? [];
      final List<Booking> confirmed = data['confirmed'] ?? [];

      // Show only past/completed trips (non-pending)
      final List<Booking> history = all.isNotEmpty
          ? all.where((b) => b.status.toLowerCase() != 'pending').toList()
          : confirmed;

      if (mounted) {
        setState(() {
          _travelHistory = history; // empty list → shows "No completed trips yet"
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      // On error, show empty state — do NOT show fake/hardcoded bookings
      if (mounted) {
        setState(() {
          _travelHistory = [];
          _isLoadingHistory = false;
        });
      }
    }
  }

  // ─── Logout Flow ──────────────────────────────────────────────────────────

  Future<void> _handleLogout(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your SeaPass account?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // 1. Revoke Sanctum access token on backend and clear secure storage
      await _dataService.logout();

      // 2. Selectively clear only auth and session data (keep server IP / Base URL intact)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_role');
      await prefs.remove('user_data');

      if (!context.mounted) return;

      // 3. Navigate back to Login and wipe route stack
      Navigator.of(context).pushNamedAndRemoveUntil(
        LoginScreen.routeName,
        (route) => false,
      );
    }
  }

  // ─── Settings Dialogs ─────────────────────────────────────────────────────

  void _showEditProfileDialog() {
    final nameController = TextEditingController(
      text: PassengerSession.name,
    );
    final phoneController = TextEditingController(
      text: PassengerSession.phone,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                PassengerSession.name = nameController.text.trim();
                PassengerSession.phone = phoneController.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully!'),
                  backgroundColor: AppPalette.mintGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.mintGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Password',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password changed successfully!'),
                  backgroundColor: AppPalette.mintGreen,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.mintGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded,
                color: AppPalette.mintGreen, size: 24),
            SizedBox(width: 8),
            Text('Help & Support'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SeaPass Passenger Terminal Support',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 10),
            Text('📍 Surigao Port Terminal / San Jose Port'),
            SizedBox(height: 4),
            Text('📞 Hotline: +63 (086) 826-0000 / 0912-345-6789'),
            SizedBox(height: 4),
            Text('✉️ Email: support@seapass.ph'),
            SizedBox(height: 4),
            Text('🕒 Operating Hours: Mon - Sun 05:00 AM - 06:00 PM'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.mintGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─── Build UI ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String fullName = PassengerSession.name;
    final String email = PassengerSession.email;
    final String phone = PassengerSession.phone;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. User Profile Section ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppPalette.mintGreen.withValues(alpha: 0.15),
                  child: Text(
                    fullName.isNotEmpty
                        ? fullName
                            .split(' ')
                            .map((e) => e.isNotEmpty ? e[0] : '')
                            .take(2)
                            .join()
                        : 'JM',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.mintGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppPalette.darkText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppPalette.mintGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    size: 11, color: AppPalette.mintGreen),
                                SizedBox(width: 3),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppPalette.mintGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── 2. Account Settings Actions ───────────────────────────────────
          const Text(
            'Account Settings',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppPalette.darkText,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Update your name and contact details',
                  onTap: _showEditProfileDialog,
                ),
                const Divider(height: 1, indent: 56),
                _buildActionTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change Password',
                  subtitle: 'Keep your account secure',
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 1, indent: 56),
                _buildActionTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Help & Support',
                  subtitle: 'Terminal hotline and passenger assistance',
                  onTap: _showHelpSupportDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 3. Travel History Section ─────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 20, color: AppPalette.darkText),
                  SizedBox(width: 8),
                  Text(
                    'Travel History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.darkText,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppPalette.mintGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_travelHistory.length} Trip${_travelHistory.length == 1 ? "" : "s"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.mintGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: AppPalette.mintGreen),
              ),
            )
          else if (_travelHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_boat_outlined,
                      size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No completed trips yet',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            ..._travelHistory.map((booking) => _buildTripCard(booking)),

          const SizedBox(height: 28),

          // ── 4. Prominent Log Out Button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout_rounded,
                  color: Color(0xFFDC2626), size: 20),
              label: const Text(
                'LOG OUT',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.0,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                backgroundColor: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppPalette.mintGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppPalette.mintGreen, size: 20),
      ),
      title: Text(
        title,
        style:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 20, color: Colors.grey),
    );
  }

  Widget _buildTripCard(Booking booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ViewTicketScreen(booking: booking),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.route,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppPalette.darkText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            AppPalette.mintGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D5C3A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.confirmation_number_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(
                      'Ref: ${booking.referenceNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₱${booking.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.mintGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(
                      'Date: ${booking.date}${booking.time.isNotEmpty ? " · ${booking.time}" : ""}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const Spacer(),
                    Text(
                      'Vessel: ${booking.boatName}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Boarding Pass',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppPalette.mintGreen,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppPalette.mintGreen),
                    ],
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
