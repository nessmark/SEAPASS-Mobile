import 'package:flutter/material.dart';

import '../widgets/app_palette.dart';
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasConsumedRouteArgs) {
      _hasConsumedRouteArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic> && args.containsKey('tabIndex')) {
        final index = args['tabIndex'];
        if (index is int && index >= 0 && index <= 2) {
          _currentIndex = index;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      const TripSchedulesScreen(),
      MyBookingsScreen(
        initialTabToBeConfirmed: _currentIndex == 1,
      ),
      const MyAccountScreen(),
    ];

    return Scaffold(
      backgroundColor: AppPalette.lightBackground,
      appBar: AppBar(
        title: Text(
          _currentIndex == 2
              ? 'My Account'
              : _currentIndex == 1
                  ? 'My Bookings'
                  : 'SeaPass Passenger App',
        ),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_boat_outlined),
            label: 'Trips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'My Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
