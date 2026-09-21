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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) {
            // Re-sync unread count when switching to advisories tab
            context.read<AdvisoryProvider>().fetchUnreadCount();
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.directions_boat_outlined),
            activeIcon: Icon(Icons.directions_boat_filled),
            label: 'Trips',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'My Bookings',
          ),
          BottomNavigationBarItem(
            icon: Consumer<AdvisoryProvider>(
              builder: (context, advisoryProvider, child) {
                final unreadCount = advisoryProvider.unreadCount;
                return Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  backgroundColor: AppPalette.danger,
                  textColor: AppPalette.white,
                  child: const Icon(Icons.campaign_outlined),
                );
              },
            ),
            activeIcon: Consumer<AdvisoryProvider>(
              builder: (context, advisoryProvider, child) {
                final unreadCount = advisoryProvider.unreadCount;
                return Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  backgroundColor: AppPalette.danger,
                  textColor: AppPalette.white,
                  child: const Icon(Icons.campaign_rounded),
                );
              },
            ),
            label: 'Advisories',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
