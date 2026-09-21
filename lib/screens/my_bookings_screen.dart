import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_palette.dart';
import '../widgets/app_skeleton.dart';
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
      padding: const EdgeInsets.fromLTRB(
          AppPalette.space24, AppPalette.space20, AppPalette.space24, 0),
      child: Column(
        children: [
          // Segmented control: pending vs confirmed
          Container(
            padding: const EdgeInsets.all(AppPalette.space4),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface2,
              borderRadius: BorderRadius.circular(AppPalette.radiusMd),
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
                const SizedBox(width: AppPalette.space4),
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
          const SizedBox(height: AppPalette.space20),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadBookings,
              color: AppColors.of(context).accent,
              child: _buildContent(activeBookings),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Booking> activeBookings) {
    if (_isLoading) {
      return const AppSkeletonList();
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppPalette.space40),
          AppEmptyState(
            icon: Icons.cloud_off_rounded,
            tone: AppPalette.danger,
            title: 'Cannot reach the terminal',
            caption: _errorMessage!,
            actionLabel: 'Retry',
            onAction: _loadBookings,
          ),
        ],
      );
    }

    if (activeBookings.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppPalette.space40),
          AppEmptyState(
            icon: _isToBeConfirmed
                ? Icons.hourglass_empty_rounded
                : Icons.confirmation_number_outlined,
            title: _isToBeConfirmed
                ? 'Nothing waiting for approval'
                : 'No confirmed tickets yet',
            caption: _isToBeConfirmed
                ? 'Bookings you submit at checkout land here while the port reviews them.'
                : 'Once the port approves a booking, its ticket and QR code appear here.',
            actionLabel: 'Refresh',
            onAction: _loadBookings,
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppPalette.space24),
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
                builder: (_) => ViewTicketScreen(booking: booking),
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
    );
  }

  Widget _buildToggleButton({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    return Material(
      color: AppPalette.transparent,
      borderRadius: BorderRadius.circular(AppPalette.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppPalette.radiusSm),
        child: AnimatedContainer(
          duration: AppPalette.duration(context),
          curve: AppPalette.motionCurve,
          padding: const EdgeInsets.symmetric(
              horizontal: AppPalette.space8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppPalette.teal500 : AppPalette.transparent,
            borderRadius: BorderRadius.circular(AppPalette.radiusSm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isSelected ? AppPalette.white : colors.text2,
                      ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppPalette.white.withValues(alpha: 0.24)
                        : colors.hairline,
                    borderRadius:
                        BorderRadius.circular(AppPalette.radiusPill),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppPalette.white : colors.text,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
