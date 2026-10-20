import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/advisory_provider.dart';
import '../widgets/app_palette.dart';
import '../widgets/assistant_button.dart';
import '../widgets/assistant/page_guide.dart';
import '../widgets/seapass_logo.dart';
import 'advisories_screen.dart';
import 'my_account_screen.dart';
import 'my_bookings_screen.dart';
import 'trip_schedules_screen.dart';

/// Primary passenger application shell with a compact floating navigation pill,
/// fluid tab transitions, system-level typography, and an explicit AI assistant slot.
class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({
    super.key,
    this.initialIndex = 0,
    this.assistantSlot,
  });

  static const String routeName = '/home';
  final int initialIndex;

  /// Dedicated integration slot for the SeaPass AI Assistant floating widget
  /// or action trigger provided by another executor.
  final Widget? assistantSlot;

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  late int _currentIndex;
  bool _hasConsumedRouteArgs = false;
  Map<String, dynamic> _bookingPrefill = const {};
  int _bookingIntentVersion = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AdvisoryProvider>().fetchUnreadCount();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasConsumedRouteArgs) {
      _hasConsumedRouteArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('tabIndex')) {
        final index = args['tabIndex'];
        if (index is int && index >= 0 && index <= 3) {
          _currentIndex = index;
        }
      }
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    if (index == 2) {
      context.read<AdvisoryProvider>().fetchUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final List<Widget> tabs = [
      TripSchedulesScreen(
        key: ValueKey(_bookingIntentVersion),
        initialBookingArgs: _bookingPrefill,
      ),
      MyBookingsScreen(
        initialTabToBeConfirmed: _currentIndex == 1,
      ),
      const AdvisoriesScreen(),
      const MyAccountScreen(),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: colors.canvas,
        extendBody: true,
        appBar: _buildAppBar(context),
        body: Stack(
          children: [
            // Tab content view
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: tabs,
              ),
            ),

            // AI Assistant Integration Point (if injected or anchored)
            if (widget.assistantSlot != null)
              Positioned(
                right: 20,
                bottom: bottomInset + 88,
                child: widget.assistantSlot!,
              ),

            // Floating Navigation Pill Dock
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + 14,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Center(
                  child: _FloatingNavBar(
                    currentIndex: _currentIndex,
                    onTabSelected: _onTabSelected,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return AppBar(
      backgroundColor: colors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: AppPalette.space20,
      title: Row(
        children: [
          const SeaPassLogo(size: 26),
          const SizedBox(width: AppPalette.space12),
          Text(
            _getTabTitle(_currentIndex),
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          widget.assistantSlot ??
              SeaPassAssistantButton(
                pageLabel: _getTabTitle(_currentIndex),
                pagePath: _getTabPath(_currentIndex),
                onNavigate: _handleAssistantNavigate,
                onNavigation: (event) {
                  if (event['page'] == 'trips' && event['args'] is Map) {
                    setState(() {
                      _bookingPrefill = Map<String, dynamic>.from(event['args'] as Map);
                      _bookingIntentVersion++;
                    });
                  }
                  _handleAssistantNavigate(event['page']?.toString() ?? '');
                },
                onGuideAction: (event) => showSeaPassPageGuide(context, _getTabPath(_currentIndex), event),
              ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: colors.hairline,
          height: 1,
        ),
      ),
    );
  }

  String _getTabTitle(int index) {
    switch (index) {
      case 1:
        return 'My Bookings';
      case 2:
        return 'Advisories';
      case 3:
        return 'My Account';
      case 0:
      default:
        return 'SeaPass';
    }
  }

  String _getTabPath(int index) {
    switch (index) {
      case 1:
        return 'bookings';
      case 2:
        return 'advisories';
      case 3:
        return 'profile';
      case 0:
      default:
        return 'trips';
    }
  }

  void _handleAssistantNavigate(String page) {
    final targetIndex = switch (page.toLowerCase()) {
      'trips' => 0,
      'bookings' => 1,
      'advisories' => 2,
      'profile' => 3,
      _ => -1,
    };
    if (targetIndex != -1 && mounted) {
      setState(() => _currentIndex = targetIndex);
    }
  }

}

/// Compact floating pill navigation bar inspired by FuturePro reference principles.
/// Features subtle surface elevation, hairline boundary, spring-animated tab selection,
/// and unread advisory badge counter.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final brightness = Theme.of(context).brightness;

    return Container(
      constraints: const BoxConstraints(maxWidth: 362),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppPalette.radiusPill),
        border: Border.all(color: colors.hairline, width: 1),
        boxShadow: AppPalette.shadows(brightness, level: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavBarItem(
            index: 0,
            currentIndex: currentIndex,
            label: 'Trips',
            activeIcon: Icons.directions_boat_filled_rounded,
            inactiveIcon: Icons.directions_boat_outlined,
            onTap: () => onTabSelected(0),
          ),
          _NavBarItem(
            index: 1,
            currentIndex: currentIndex,
            label: 'Bookings',
            activeIcon: Icons.receipt_long_rounded,
            inactiveIcon: Icons.receipt_long_outlined,
            onTap: () => onTabSelected(1),
          ),
          _NavBarItem(
            index: 2,
            currentIndex: currentIndex,
            label: 'Advisories',
            activeIcon: Icons.campaign_rounded,
            inactiveIcon: Icons.campaign_outlined,
            showAdvisoryBadge: true,
            onTap: () => onTabSelected(2),
          ),
          _NavBarItem(
            index: 3,
            currentIndex: currentIndex,
            label: 'Account',
            activeIcon: Icons.person_rounded,
            inactiveIcon: Icons.person_outline_rounded,
            onTap: () => onTabSelected(3),
          ),
        ],
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.index,
    required this.currentIndex,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    this.showAdvisoryBadge = false,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool showAdvisoryBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = index == currentIndex;
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    Widget iconWidget = Icon(
      isSelected ? activeIcon : inactiveIcon,
      size: 20,
      color: isSelected ? colors.accent : colors.text3,
    );

    if (showAdvisoryBadge) {
      iconWidget = Consumer<AdvisoryProvider>(
        builder: (context, provider, child) {
          final count = provider.unreadCount;
          return Badge(
            isLabelVisible: count > 0,
            label: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppPalette.white,
              ),
            ),
            backgroundColor: AppPalette.danger,
            child: child!,
          );
        },
        child: iconWidget,
      );
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppPalette.radiusPill),
          child: AnimatedContainer(
            duration: AppPalette.motionFast,
            curve: AppPalette.motionCurve,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? colors.tint : Colors.transparent,
              borderRadius: BorderRadius.circular(AppPalette.radiusPill),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(height: 2),
                Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colors.accent : colors.text3,
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
