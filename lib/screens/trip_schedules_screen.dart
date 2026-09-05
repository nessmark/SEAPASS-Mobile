import 'dart:async';

import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../services/api_exception.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../utils/manila_clock.dart';
import '../widgets/app_palette.dart';
import 'booking_checkout_screen.dart';

class TripSchedulesScreen extends StatefulWidget {
  const TripSchedulesScreen({super.key});

  @override
  State<TripSchedulesScreen> createState() => _TripSchedulesScreenState();
}

class _TripSchedulesScreenState extends State<TripSchedulesScreen> {
  // ─── Route options ───────────────────────────────────────────────────────────
  static const List<String> _ports = ['Surigao', 'San Jose'];

  String _from = 'Surigao';
  String _to = 'San Jose';
  late DateTime _selectedDate;

  // ─── Async state ─────────────────────────────────────────────────────────────
  Future<List<Schedule>>? _schedulesFuture;
  bool _hasSearched = false;

  final PassengerDataService _dataService = const PassengerDataService();

  @override
  void initState() {
    super.initState();
    // Default to today (Manila-friendly ISO date, times are local)
    _selectedDate = DateTime.now();
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  void _search() {
    setState(() {
      _hasSearched = true;
      _schedulesFuture = _dataService.fetchSchedules(
        date: _selectedDate,
        from: _from,
        to: _to,
      );
    });
  }

  void _retry() => _search();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppPalette.mintGreen,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _hasSearched = true;
        _schedulesFuture = _dataService.fetchSchedules(
          date: picked,
          from: _from,
          to: _to,
        );
      });
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          _buildGreeting(),
          const SizedBox(height: 20),

          // Search card
          _buildSearchCard(),
          const SizedBox(height: 28),

          // Results section
          if (_hasSearched) ...[
            const Text(
              'Available Schedules',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppPalette.darkText,
              ),
            ),
            const SizedBox(height: 12),
            _buildScheduleResults(),
          ],
        ],
      ),
    );
  }

  // ─── Greeting ────────────────────────────────────────────────────────────────

  Widget _buildGreeting() {
    final String rawName = PassengerSession.name.trim();
    final String displayName = rawName.isNotEmpty ? rawName : 'Passenger';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(color: AppPalette.darkText, fontSize: 22),
            children: [
              const TextSpan(text: 'Welcome,\n'),
              TextSpan(
                text: '$displayName 👋',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  color: AppPalette.mintGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Find your Bangka for your trip 🚢',
          style: TextStyle(
            fontSize: 14,
            color: AppPalette.subtleGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── Search card ─────────────────────────────────────────────────────────────

  Widget _buildSearchCard() {
    final dateLabel = ManilaClock.toQueryDate(_selectedDate) ==
            ManilaClock.toQueryDate(DateTime.now())
        ? 'Today, ${_formatDisplayDate(_selectedDate)}'
        : _formatDisplayDate(_selectedDate);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCHEDULE SEARCH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppPalette.subtleGrey,
            ),
          ),
          const SizedBox(height: 14),

          // From / To row
          Row(
            children: [
              Expanded(child: _buildPortDropdown('From', _from, (v) {
                if (v != null) setState(() => _from = v);
              })),
              const SizedBox(width: 10),
              // Swap button
              GestureDetector(
                onTap: () => setState(() {
                  final tmp = _from;
                  _from = _to;
                  _to = tmp;
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.mintGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: AppPalette.mintGreen,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildPortDropdown('To', _to, (v) {
                if (v != null) setState(() => _to = v);
              })),
            ],
          ),
          const SizedBox(height: 12),

          // Date picker
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 20, color: AppPalette.subtleGrey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppPalette.darkText,
                      ),
                    ),
                  ),
                  const Icon(Icons.edit_calendar_outlined,
                      size: 18, color: AppPalette.subtleGrey),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text(
                'SEARCH',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.8,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.mintGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortDropdown(
    String label,
    String value,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppPalette.mintGreen, width: 1.5),
        ),
      ),
      items: _ports
          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
          .toList(),
      onChanged: onChanged,
    );
  }

  // ─── Results ─────────────────────────────────────────────────────────────────

  Widget _buildScheduleResults() {
    return FutureBuilder<List<Schedule>>(
      future: _schedulesFuture,
      builder: (context, snapshot) {
        // ── Loading ──
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        // ── Error ──
        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Unable to load schedules right now. Please check your network and try again.';

          return _buildErrorState(message);
        }

        // ── Empty ──
        final schedules = snapshot.data ?? [];
        if (schedules.isEmpty) {
          return _buildEmptyState();
        }

        // ── List ──
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: schedules.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) =>
              _buildScheduleCard(schedules[index]),
        );
      },
    );
  }

  // ─── State widgets ───────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ScheduleSkeleton(),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 52, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.mintGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_boat_outlined,
              size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No schedules found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no available trips for $_from → $_to on the selected date.\nTry a different date or route.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─── Schedule card ───────────────────────────────────────────────────────────

  Widget _buildScheduleCard(Schedule schedule) {
    final bool soldOut = schedule.availableSeats <= 0;
    final bool canBook = !soldOut && schedule.isBookableInManila;

    return GestureDetector(
      onTap: canBook
          ? () => Navigator.of(context).pushNamed(
                BookingCheckoutScreen.routeName,
                arguments: schedule,
              )
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canBook
                ? AppPalette.mintGreen.withValues(alpha: 0.4)
                : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Route + status badge row
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${schedule.from} → ${schedule.to}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.darkText,
                    ),
                  ),
                ),
                _buildStatusBadge(schedule, soldOut),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Departure + boat + seats row
            Row(
              children: [
                _buildInfoChip(
                  Icons.access_time_rounded,
                  schedule.time.isNotEmpty
                      ? schedule.time
                      : schedule.departureTime,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.directions_boat_outlined,
                  schedule.boatName.isNotEmpty
                      ? schedule.boatName
                      : 'N/A',
                ),
                const Spacer(),
                if (!soldOut)
                  Text(
                    '${schedule.availableSeats} seats left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: schedule.availableSeats < 5
                          ? Colors.red.shade400
                          : AppPalette.mintGreen,
                    ),
                  ),
              ],
            ),
            if (canBook) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppPalette.mintGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Book Now →',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Schedule schedule, bool soldOut) {
    Color bg;
    Color fg;
    String label;

    if (soldOut) {
      bg = Colors.red.shade50;
      fg = Colors.red.shade400;
      label = 'Sold Out';
    } else if (!schedule.isBookableInManila) {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade700;
      label = 'Departed';
    } else {
      bg = AppPalette.mintGreen.withValues(alpha: 0.12);
      fg = AppPalette.mintGreen;
      label = schedule.status.isNotEmpty ? schedule.status : 'Available';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppPalette.subtleGrey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppPalette.darkText),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// ─── Skeleton loader ─────────────────────────────────────────────────────────

class _ScheduleSkeleton extends StatefulWidget {
  @override
  State<_ScheduleSkeleton> createState() => _ScheduleSkeletonState();
}

class _ScheduleSkeletonState extends State<_ScheduleSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(width: 180, height: 14),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _bar(width: 80, height: 12),
                const SizedBox(width: 12),
                _bar(width: 100, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}