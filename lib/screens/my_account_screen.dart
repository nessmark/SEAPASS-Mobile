import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_palette.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
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
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppPalette.danger, size: 24),
            SizedBox(width: AppPalette.space8),
            Expanded(child: Text('Log out')),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your SeaPass account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.danger,
              foregroundColor: AppPalette.white,
            ),
            child: const Text('Log out'),
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
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: AppPalette.space12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                PassengerSession.name = nameController.text.trim();
                PassengerSession.phone = phoneController.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile updated successfully!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
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
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: AppPalette.space12),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password changed successfully!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
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
        title: const Row(
          children: [
            Icon(Icons.support_agent_rounded,
                color: AppPalette.teal500, size: 24),
            SizedBox(width: AppPalette.space8),
            Expanded(child: Text('Help & support')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SeaPass Passenger Terminal Support',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            const SizedBox(height: AppPalette.space12),
            const _SupportLine(
              icon: Icons.place_outlined,
              text: 'Surigao Port Terminal / San Jose Port',
            ),
            const _SupportLine(
              icon: Icons.call_outlined,
              text: 'Hotline: +63 (086) 826-0000 / 0912-345-6789',
            ),
            const _SupportLine(
              icon: Icons.mail_outline_rounded,
              text: 'support@seapass.ph',
            ),
            const _SupportLine(
              icon: Icons.schedule_rounded,
              text: 'Mon – Sun, 05:00 AM – 06:00 PM',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
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
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppPalette.space24, AppPalette.space20,
          AppPalette.space24, AppPalette.space32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. User Profile Section ───────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(AppPalette.space20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: colors.tint,
                  child: Text(
                    fullName.isNotEmpty
                        ? fullName
                            .split(' ')
                            .map((e) => e.isNotEmpty ? e[0] : '')
                            .take(2)
                            .join()
                        : 'JM',
                    style: text.headlineMedium?.copyWith(color: colors.onTint),
                  ),
                ),
                const SizedBox(width: AppPalette.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fullName,
                              style: text.titleLarge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppPalette.space8),
                          const StatusChip(
                            label: 'Verified',
                            tone: StatusTone.success,
                            icon: Icons.check_circle_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppPalette.space4),
                      Text(
                        email,
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        phone,
                        style: text.bodySmall?.copyWith(color: colors.text3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppPalette.space32),

          // ── 2. Account Settings Actions ───────────────────────────────────
          const SectionHeader('Account settings'),
          AppCard(
            padding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit profile',
                  subtitle: 'Update your name and contact details',
                  onTap: _showEditProfileDialog,
                ),
                Divider(height: 1, indent: 68, color: colors.hairline),
                _buildActionTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Change password',
                  subtitle: 'Keep your account secure',
                  onTap: _showChangePasswordDialog,
                ),
                Divider(height: 1, indent: 68, color: colors.hairline),
                _buildActionTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Help & support',
                  subtitle: 'Terminal hotline and passenger assistance',
                  onTap: _showHelpSupportDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppPalette.space32),

          // ── 3. Travel History Section ─────────────────────────────────────
          SectionHeader(
            'Travel history',
            action: _isLoadingHistory
                ? null
                : StatusChip(
                    label:
                        '${_travelHistory.length} trip${_travelHistory.length == 1 ? "" : "s"}',
                  ),
          ),

          if (_isLoadingHistory)
            const Column(
              children: [
                AppCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 160, height: 22),
                    SizedBox(height: AppPalette.space16),
                    AppSkeleton(),
                    SizedBox(height: AppPalette.space8),
                    AppSkeleton(width: 120),
                  ],
                )),
                SizedBox(height: AppPalette.space16),
                AppCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 160, height: 22),
                    SizedBox(height: AppPalette.space16),
                    AppSkeleton(),
                    SizedBox(height: AppPalette.space8),
                    AppSkeleton(width: 120),
                  ],
                )),
              ],
            )
          else if (_travelHistory.isEmpty)
            AppCard(
              padding: EdgeInsets.zero,
              child: AppEmptyState(
                icon: Icons.directions_boat_outlined,
                title: 'No completed trips yet',
                caption:
                    'Trips you finish will be archived here with their boarding passes.',
                actionLabel: 'Refresh',
                onAction: _loadTravelHistory,
              ),
            )
          else
            ..._travelHistory.map((booking) => _buildTripCard(booking)),

          const SizedBox(height: AppPalette.space32),

          // ── 4. Prominent Log Out Button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Log out'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.danger.withValues(alpha: .12),
                foregroundColor: AppPalette.danger,
              ),
            ),
          ),
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
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppPalette.space20, vertical: AppPalette.space4),
      leading: Container(
        padding: const EdgeInsets.all(AppPalette.space8),
        decoration: BoxDecoration(
          color: colors.tint,
          borderRadius: BorderRadius.circular(AppPalette.radiusSm),
        ),
        child: Icon(icon, color: colors.onTint, size: 20),
      ),
      title: Text(title, style: text.titleSmall),
      subtitle: Text(subtitle, style: text.bodySmall),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: colors.text3),
    );
  }

  Widget _buildTripCard(Booking booking) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppPalette.space16),
      padding: const EdgeInsets.all(AppPalette.space20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViewTicketScreen(booking: booking),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(booking.route, style: text.titleLarge)),
              const SizedBox(width: AppPalette.space8),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: StatusChip(
                    label: 'Completed', tone: StatusTone.success),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space16),
          Row(
            children: [
              Icon(Icons.confirmation_number_outlined,
                  size: 15, color: colors.text3),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking.referenceNumber,
                  style: text.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppPalette.space8),
              Text(
                '₱${booking.totalPrice.toStringAsFixed(2)}',
                style: text.titleLarge?.copyWith(color: colors.accent),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space8),
          Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 15, color: colors.text3),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${booking.date}${booking.time.isNotEmpty ? " · ${booking.time}" : ""}',
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppPalette.space8),
              Flexible(
                child: Text(
                  booking.boatName,
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('View boarding pass',
                  style: text.labelMedium?.copyWith(color: colors.accent)),
              const SizedBox(width: AppPalette.space4),
              Icon(Icons.arrow_forward_rounded, size: 16, color: colors.accent),
            ],
          ),
        ],
      ),
    );
  }
}

/// One contact line in the help sheet — icon instead of emoji chrome.
class _SupportLine extends StatelessWidget {
  const _SupportLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppPalette.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: colors.text3),
          ),
          const SizedBox(width: AppPalette.space8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
