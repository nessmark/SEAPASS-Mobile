import 'dart:async';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/schedule.dart';
import '../services/api_exception.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../widgets/app_card.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/app_palette.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/section_header.dart';
import '../widgets/status_chip.dart';
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
      padding: const EdgeInsets.fromLTRB(AppPalette.space24, AppPalette.space20,
          AppPalette.space24, AppPalette.space32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          _buildGreeting(),
          const SizedBox(height: AppPalette.space24),

          // Search card
          _buildSearchCard(),
          const SizedBox(height: AppPalette.space32),

          // Results section
          if (_hasSearched) ...[
            SectionHeader('Available trips', caption: '$_from → $_to'),
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
    final text = Theme.of(context).textTheme;
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$displayName!',
          style: text.headlineLarge?.copyWith(color: colors.accent),
        ),
        Text('Sakay na!', style: text.headlineMedium),
        const SizedBox(height: AppPalette.space8),
        Text(
          'Find your bangka for the trip ahead.',
          style: text.bodySmall,
        ),
      ],
    );
  }

  // ─── Search card ─────────────────────────────────────────────────────────────

  Widget _buildSearchCard() {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppPalette.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PLAN YOUR TRIP', style: text.labelSmall),
          const SizedBox(height: AppPalette.space16),

          // From / To fields, with the swap control alongside them
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPortDropdown('From', _from, (v) {
                      if (v != null) {
                        setState(() => _from = v);
                        _loadAvailableDates();
                        _search();
                      }
                    }),
                    const SizedBox(height: AppPalette.space12),
                    _buildPortDropdown('To', _to, (v) {
                      if (v != null) {
                        setState(() => _to = v);
                        _loadAvailableDates();
                        _search();
                      }
                    }),
                  ],
                ),
              ),
              const SizedBox(width: AppPalette.space12),
              IconButton(
                onPressed: () {
                  setState(() {
                    final tmp = _from;
                    _from = _to;
                    _to = tmp;
                  });
                  _loadAvailableDates();
                  _search();
                },
                tooltip: 'Swap ports',
                iconSize: 20,
                style: IconButton.styleFrom(
                  backgroundColor: colors.tint,
                  foregroundColor: colors.onTint,
                  fixedSize: const Size(44, 44),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.swap_vert_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space12),

          // ── Inline Calendar Widget ─────────────────────────────────────
          TableCalendar(
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
              titleTextStyle: text.titleSmall ?? const TextStyle(),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: colors.accent,
                size: 24,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: colors.accent,
                size: 24,
              ),
              headerPadding: const EdgeInsets.symmetric(vertical: AppPalette.space8),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: text.labelSmall ?? const TextStyle(),
              weekendStyle: text.labelSmall ?? const TextStyle(),
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
                color: colors.tint,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: colors.onTint,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              // Default days
              defaultTextStyle: TextStyle(fontSize: 14, color: colors.text),
              weekendTextStyle: TextStyle(fontSize: 14, color: colors.text2),
              outsideTextStyle: TextStyle(fontSize: 14, color: colors.text3),
              disabledTextStyle: TextStyle(fontSize: 14, color: colors.text3),
              cellMargin: const EdgeInsets.all(AppPalette.space4),
            ),
            // ── Availability dot markers ─────────────────────────────
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (_hasTripsOnDay(date)) {
                  return Positioned(
                    bottom: 3,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.accent,
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
      isExpanded: true,
      borderRadius: BorderRadius.circular(AppPalette.radiusMd),
      decoration: InputDecoration(labelText: label),
      items: _ports
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis),
              ))
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
          separatorBuilder: (_, __) => const SizedBox(height: AppPalette.space12),
          itemBuilder: (context, index) =>
              _buildScheduleCard(schedules[index]),
        );
      },
    );
  }

  // ─── State widgets ───────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Column(
      children: [
        _ScheduleSkeleton(),
        SizedBox(height: AppPalette.space12),
        _ScheduleSkeleton(),
        SizedBox(height: AppPalette.space12),
        _ScheduleSkeleton(),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: AppEmptyState(
        icon: Icons.wifi_off_rounded,
        tone: AppPalette.danger,
        title: 'Cannot load schedules',
        caption: message,
        actionLabel: 'Retry',
        onAction: _retry,
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppCard(
      padding: EdgeInsets.zero,
      child: AppEmptyState(
        icon: Icons.directions_boat_outlined,
        title: 'No trips on this date',
        caption:
            'Nothing is sailing $_from → $_to on the date you picked. Try another day or flip the route.',
        actionLabel: 'Refresh',
        onAction: _retry,
      ),
    );
  }

  // ─── Schedule card ───────────────────────────────────────────────────────────

  Widget _buildScheduleCard(Schedule schedule) {
    final bool soldOut = schedule.availableSeats <= 0;
    final bool canBook = !soldOut && schedule.isBookableInManila;
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppPalette.space20),
      onTap: canBook
          ? () => Navigator.of(context).pushNamed(
                BookingCheckoutScreen.routeName,
                arguments: schedule,
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route + status chip row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        schedule.from,
                        style: text.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_right_alt_rounded,
                          size: 18, color: colors.text3),
                    ),
                    Flexible(
                      child: Text(
                        schedule.to,
                        style: text.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppPalette.space8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _buildStatusChip(schedule, soldOut),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space16),

          // Departure + boat + seats row
          Wrap(
            spacing: AppPalette.space16,
            runSpacing: AppPalette.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildInfoChip(
                Icons.access_time_rounded,
                schedule.time.isNotEmpty
                    ? schedule.time
                    : schedule.departureTime,
              ),
              _buildInfoChip(
                Icons.directions_boat_outlined,
                schedule.boatName.isNotEmpty ? schedule.boatName : 'N/A',
              ),
              if (!soldOut)
                Text(
                  '${schedule.availableSeats} seats left',
                  style: text.labelMedium?.copyWith(
                    color: schedule.availableSeats < 5
                        ? AppPalette.danger
                        : colors.accent,
                  ),
                ),
            ],
          ),
          if (canBook) ...[
            const SizedBox(height: AppPalette.space16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Book now',
                    style: text.labelLarge?.copyWith(color: colors.accent)),
                const SizedBox(width: AppPalette.space4),
                Icon(Icons.arrow_forward_rounded, size: 18, color: colors.accent),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(Schedule schedule, bool soldOut) {
    if (soldOut) {
      return const StatusChip(label: 'Sold out', tone: StatusTone.danger);
    }
    if (!schedule.isBookableInManila) {
      return const StatusChip(label: 'Departed', tone: StatusTone.warning);
    }
    return StatusChip(
      label: schedule.status.isNotEmpty ? schedule.status : 'Available',
      tone: StatusTone.success,
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: colors.text3),
        const SizedBox(width: AppPalette.space4),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

// ─── Skeleton loader ─────────────────────────────────────────────────────────

class _ScheduleSkeleton extends StatelessWidget {
  const _ScheduleSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(AppPalette.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 180, height: 22),
          SizedBox(height: AppPalette.space16),
          Row(
            children: [
              AppSkeleton(width: 80, height: 14),
              SizedBox(width: AppPalette.space16),
              AppSkeleton(width: 110, height: 14),
            ],
          ),
        ],
      ),
    );
  }
}
