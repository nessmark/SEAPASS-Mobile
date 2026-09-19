import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../widgets/app_palette.dart';
import '../widgets/booking_card.dart';
import 'view_ticket_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, this.initialTabToBeConfirmed = true});

  final bool initialTabToBeConfirmed;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late bool _isToBeConfirmed;
  bool _isLoading = true;
  String? _errorMessage;

  List<Booking> _pendingBookings = [];
  List<Booking> _confirmedBookings = [];
  Timer? _pollingTimer;

  final PassengerDataService _dataService = const PassengerDataService();

  @override
  void initState() {
    super.initState();
    _isToBeConfirmed = widget.initialTabToBeConfirmed;
    _loadBookings();

    // Setup periodic polling to auto-sync status updates from admin
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        _loadBookings(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBookings({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final int passengerId = PassengerSession.passengerId;
      final String passengerName = PassengerSession.name;
      final data = await _dataService.fetchPassengerBookings(
        passengerId: passengerId > 0 ? passengerId : null,
        passengerName: passengerId <= 0 && passengerName.isNotEmpty
            ? passengerName
            : null,
      );

      if (!mounted) return;

      setState(() {
        _pendingBookings = data['pending'] ?? [];
        _confirmedBookings = data['confirmed'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBookings =
        _isToBeConfirmed ? _pendingBookings : _confirmedBookings;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Toggle Buttons matching image_7de9fd.png
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleButton(
                    title: 'To be confirmed',
                    count: _pendingBookings.length,
                    isSelected: _isToBeConfirmed,
                    onTap: () => setState(() => _isToBeConfirmed = true),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildToggleButton(
                    title: 'Confirmed',
                    count: _confirmedBookings.length,
                    isSelected: !_isToBeConfirmed,
                    onTap: () => setState(() => _isToBeConfirmed = false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBookings,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? ListView(
                          children: [
                            const SizedBox(height: 60),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.cloud_off,
                                      size: 48, color: Colors.grey),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadBookings,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : activeBookings.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        _isToBeConfirmed
                                            ? Icons.hourglass_empty_rounded
                                            : Icons.confirmation_number_outlined,
                                        size: 56,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _isToBeConfirmed
                                            ? 'No bookings waiting to be confirmed.'
                                            : 'No confirmed tickets yet.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _isToBeConfirmed
                                            ? 'Bookings submitted from checkout will appear here.'
                                            : 'Once your booking is approved by admin, your ticket & QR code will appear here.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              itemCount: activeBookings.length,
                              itemBuilder: (context, index) {
                                final booking = activeBookings[index];
                                return BookingCard(
                                  booking: booking,
                                  onViewTicket: () async {
                                    // Pause background polling while viewing ticket details
                                    // to prevent status from visually "changing" mid-view.
                                    _pollingTimer?.cancel();
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ViewTicketScreen(booking: booking),
                                      ),
                                    );
                                    // Resume polling after returning from detail view
                                    if (mounted) {
                                      _pollingTimer = Timer.periodic(
                                        const Duration(seconds: 5),
                                        (_) {
                                          if (mounted) _loadBookings(silent: true);
                                        },
                                      );
                                      _loadBookings(silent: true);
                                    }
                                  },
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.mintGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
