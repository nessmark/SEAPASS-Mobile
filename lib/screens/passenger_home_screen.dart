import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/advisory_provider.dart';
import '../widgets/app_palette.dart';
import 'advisories_screen.dart';
import 'my_account_screen.dart';
import 'my_bookings_screen.dart';
import 'trip_schedules_screen.dart';

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key, this.initialIndex = 0});

  static const String routeName = '/home';
  final int initialIndex;

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen> {
  late int _currentIndex;
  bool _hasConsumedRouteArgs = false;

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

  String get _appBarTitle {
    switch (_currentIndex) {
      case 3:
        return 'My Account';
      case 2:
        return 'Travel Advisories';
      case 1:
        return 'My Bookings';
      case 0:
      default:
        return 'SeaPass';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      const TripSchedulesScreen(),
      MyBookingsScreen(
        initialTabToBeConfirmed: _currentIndex == 1,
      ),
      const AdvisoriesScreen(),
      const MyAccountScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      appBar: AppBar(
        title: Text(_appBarTitle),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) {
            // Re-sync unread count when switching to advisories tab
            context.read<AdvisoryProvider>().fetchUnreadCount();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_boat_outlined),
            selectedIcon: Icon(Icons.directions_boat_filled),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: _AdvisoryBadge(child: Icon(Icons.campaign_outlined)),
            selectedIcon: _AdvisoryBadge(child: Icon(Icons.campaign_rounded)),
            label: 'Advisories',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

/// Unread-advisory count bubble, kept out of the destination list so the
/// destinations themselves stay const.
class _AdvisoryBadge extends StatelessWidget {
  const _AdvisoryBadge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Consumer<AdvisoryProvider>(
        builder: (context, advisoryProvider, _) {
          final unreadCount = advisoryProvider.unreadCount;
          return Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            backgroundColor: AppPalette.danger,
            textColor: AppPalette.white,
            child: child,
          );
        },
      );
}
