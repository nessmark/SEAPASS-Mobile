import 'dart:async';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/schedule.dart';
import '../services/api_exception.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../widgets/app_palette.dart';
import '../widgets/app_card.dart';
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
  late DateTime _focusedDay;

  // ─── Async state ─────────────────────────────────────────────────────────────
  Future<List<Schedule>>? _schedulesFuture;
  bool _hasSearched = false;

  // ─── Calendar availability markers ──────────────────────────────────────────
  Set<DateTime> _availableDates = {};

  final PassengerDataService _dataService = const PassengerDataService();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedDay = _selectedDate;
    _loadAvailableDates();
    _search();
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

  /// Fetch dates that have available trips for the current route and focused month.
  Future<void> _loadAvailableDates() async {
    try {
      final month =
          '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';
      final dates = await _dataService.fetchAvailableDates(
        from: _from,
        to: _to,
        month: month,
      );
      if (mounted) setState(() => _availableDates = dates);
    } catch (_) {
      // Silently fail — calendar still works, just without green dots
    }
  }

  /// Check if a given day has available trips.
  bool _hasTripsOnDay(DateTime day) {
    return _availableDates.any(
      (d) => d.year == day.year && d.month == day.month && d.day == day.day,
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
            Text(
              'Available Schedules',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.of(context).text,
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
            style: TextStyle(color: AppColors.of(context).text, fontSize: 22),
            children: [
              
              TextSpan(
                text: '$displayName!',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 26,
                  color: AppPalette.teal500,
                ),
              ),
              const TextSpan(text: '\nSakay na!'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Find your Bangka for your trip ',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.of(context).text3,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── Search card ─────────────────────────────────────────────────────────────

  Widget _buildSearchCard() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan your trip',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              color: AppColors.of(context).text3,
            ),
          ),
          const SizedBox(height: 14),

          // From / To row
          Row(
            children: [
              Expanded(child: _buildPortDropdown('From', _from, (v) {
                if (v != null) {
                  setState(() => _from = v);
                  _loadAvailableDates();
                  _search();
                }
              })),
              const SizedBox(width: 10),
              // Swap button
              GestureDetector(
                onTap: () {
                  setState(() {
                    final tmp = _from;
                    _from = _to;
                    _to = tmp;
                  });
                  _loadAvailableDates();
                  _search();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.teal500.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: AppPalette.teal500,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _buildPortDropdown('To', _to, (v) {
                if (v != null) {
                  setState(() => _to = v);
                  _loadAvailableDates();
                  _search();
                }
              })),
            ],
          ),
          const SizedBox(height: 12),

          // ── Inline Calendar Widget ─────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              
              borderRadius: BorderRadius.circular(14),
            ),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 1)),
              lastDay: DateTime.now().add(const Duration(days: 1825)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDate = selected;
                  _focusedDay = focused;
                });
                _search(); // Auto-search on date tap
              },
              calendarFormat: CalendarFormat.month,
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              startingDayOfWeek: StartingDayOfWeek.monday,
              daysOfWeekHeight: 28,
              rowHeight: 44,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.of(context).text,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left_rounded,
                  color: AppPalette.teal500,
                  size: 24,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.teal500,
                  size: 24,
                ),
                headerPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).text3,
                ),
                weekendStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.of(context).text3,
                ),
              ),
              calendarStyle: CalendarStyle(
                // Selected day (user tapped)
                selectedDecoration: const BoxDecoration(
                  color: AppPalette.teal500,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: AppPalette.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                // Today highlight
                todayDecoration: BoxDecoration(
                  color: AppPalette.teal500.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: AppColors.of(context).text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                // Default days
                defaultTextStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.of(context).text,
                ),
                weekendTextStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.of(context).text3,
                ),
                outsideTextStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.of(context).hairline,
                ),
                disabledTextStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.of(context).hairline,
                ),
                cellMargin: const EdgeInsets.all(4),
              ),
              // ── Green availability dot markers ───────────────────────
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (_hasTripsOnDay(date)) {
                    return Positioned(
                      bottom: 3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppPalette.teal500,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadAvailableDates();
              },
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
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        
        
        
        
        
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
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 52, color: AppPalette.danger),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.of(context).text2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.teal500,
              foregroundColor: AppPalette.white,
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
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_boat_outlined,
              size: 52, color: AppColors.of(context).text3),
          const SizedBox(height: 16),
          Text(
            'No schedules found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.of(context).text2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no available trips for $_from → $_to on the selected date.\nTry a different date or route.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.of(context).text3),
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
        duration: AppPalette.duration(context),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          borderRadius: BorderRadius.circular(16),
          
          boxShadow: [
            BoxShadow(
              color: AppPalette.ink.withValues(alpha: 0.04),
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.of(context).text,
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
                          ? AppPalette.danger
                          : AppPalette.teal500,
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
                    color: AppPalette.teal500,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Book Now →',
                    style: TextStyle(
                      color: AppPalette.white,
                      fontWeight: FontWeight.w600,
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
      bg = AppPalette.danger.withValues(alpha: .12);
      fg = AppPalette.danger;
      label = 'Sold Out';
    } else if (!schedule.isBookableInManila) {
      bg = AppPalette.warning.withValues(alpha: .12);
      fg = AppPalette.warning;
      label = 'Departed';
    } else {
      bg = AppPalette.teal500.withValues(alpha: 0.12);
      fg = AppPalette.teal500;
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
        Icon(icon, size: 14, color: AppColors.of(context).text3),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: AppColors.of(context).text),
        ),
      ],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
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
      CurvedAnimation(parent: _controller, curve: AppPalette.motionCurve),
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
      child: AppCard(
        padding: const EdgeInsets.all(16),
        
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
        color: AppColors.of(context).surface2,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}