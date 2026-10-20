import '../widgets/assistant/page_guide.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/schedule.dart';
import '../models/route_fare.dart';
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

/// Primary trip schedule discovery and booking screen.
/// Implements responsive port switching, a 21-day horizontal date selector,
/// highly legible departure schedule rows, and reliable loading/settle states.
class TripSchedulesScreen extends StatefulWidget {
  const TripSchedulesScreen({super.key, this.initialBookingArgs = const {}});
  final Map<String, dynamic> initialBookingArgs;

  @override
  State<TripSchedulesScreen> createState() => _TripSchedulesScreenState();
}

class _TripSchedulesScreenState extends State<TripSchedulesScreen> {
  static const List<String> _ports = ['Surigao', 'San Jose'];

  String _from = 'Surigao';
  String _to = 'San Jose';
  late DateTime _selectedDate;
  late DateTime _focusedDay;

  Future<List<Schedule>>? _schedulesFuture;
  Future<RouteFare>? _fareFuture;
  int? _requestedTripId;
  int _requestedSeats = 1;
  bool _hasSearched = false;
  Set<DateTime> _availableDates = {};

  final PassengerDataService _dataService = const PassengerDataService();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _focusedDay = _selectedDate;
    final args = widget.initialBookingArgs;
    final date = DateTime.tryParse(args['date']?.toString() ?? '');
    if (date != null && !DateUtils.dateOnly(date).isBefore(DateUtils.dateOnly(DateTime.now()))) {
      _selectedDate = date;
      _focusedDay = date;
    }
    final route = args['route']?.toString().toLowerCase() ?? '';
    if (route.startsWith('san jose') || route.startsWith('dinagat')) {
      _from = 'San Jose';
      _to = 'Surigao';
    }
    _requestedTripId = int.tryParse(args['trip_id']?.toString() ?? '');
    _requestedSeats = (int.tryParse(args['seats']?.toString() ?? '') ?? 1).clamp(1, 10);
    _loadAvailableDates();
    _search();
  }

  void _search() {
    setState(() {
      _hasSearched = true;
      _schedulesFuture = _dataService.fetchSchedules(
        date: _selectedDate,
        from: _from,
        to: _to,
      );
      _fareFuture = _dataService.fetchFareForRoute('', from: _from, to: _to);
    });
  }

  void _retry() => _search();

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
      // Non-blocking availability dot overlay
    }
  }

  bool _hasTripsOnDay(DateTime day) {
    return _availableDates.any(
      (d) => d.year == day.year && d.month == day.month && d.day == day.day,
    );
  }

  void _swapPorts() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    });
    _loadAvailableDates();
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Generous bottom padding ensures floating navigation dock never obscures content
      padding: const EdgeInsets.fromLTRB(
        AppPalette.space24,
        AppPalette.space20,
        AppPalette.space24,
        AppPalette.space32 + 96,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGreeting(),
          const SizedBox(height: AppPalette.space20),
          _buildRouteAndDateCard().guide('route_selector'),
          const SizedBox(height: AppPalette.space24),
          if (_hasSearched) ...[
            if (_requestedTripId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Selected trip #$_requestedTripId · $_requestedSeats passenger${_requestedSeats == 1 ? '' : 's'}. Review the sailing and choose your seats.'),
              ),
            SectionHeader(
              'Scheduled Sailings',
              caption: '$_from → $_to • ${_formatDateDisplay(_selectedDate)}',
            ),
            _buildScheduleResults().guide('schedules_list'),
          ],
        ],
      ),
    );
  }

  Widget _buildGreeting() {
    final String rawName = PassengerSession.name.trim();
    final String displayName = rawName.isNotEmpty ? rawName : 'Passenger';
    final text = Theme.of(context).textTheme;
    final colors = AppColors.of(context);
    final String firstName = displayName.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Sakay na, ', style: text.headlineMedium),
            Flexible(
              child: Text(
                firstName,
                style: text.headlineMedium?.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Daily passenger lancha trips between Surigao and Dinagat Islands.',
          style: text.bodySmall?.copyWith(color: colors.text3),
        ),
      ],
    );
  }

  Widget _buildRouteAndDateCard() {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppPalette.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Port Route Switcher (Grouped modern transit controls) ──
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildPortSelectorRow(
                      label: 'ORIGIN PORT',
                      portName: _from,
                      subtitle: _from == 'Surigao'
                          ? 'Lipata / Boulevard Ferry Terminal'
                          : 'San Jose Dinagat Port',
                      isOrigin: true,
                    ),
                    const Divider(height: 16),
                    _buildPortSelectorRow(
                      label: 'DESTINATION PORT',
                      portName: _to,
                      subtitle: _to == 'San Jose'
                          ? 'Dinagat Islands Main Port'
                          : 'Surigao City Ferry Terminal',
                      isOrigin: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppPalette.space16),
              Semantics(
                button: true,
                label: 'Swap origin and destination ports',
                child: IconButton(
                  onPressed: _swapPorts,
                  tooltip: 'Swap ports',
                  style: IconButton.styleFrom(
                    backgroundColor: colors.tint,
                    foregroundColor: colors.onTint,
                    fixedSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppPalette.radiusMd),
                      side: BorderSide(color: colors.hairline, width: 1),
                    ),
                  ),
                  icon: const Icon(Icons.swap_vert_rounded, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space20),

          // ── Date Picker Rail Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRAVEL DATE',
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: colors.text3,
                ),
              ),
              Text(
                _formatMonthYear(_focusedDay),
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.text2,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space12),

          // ── 21-Day Horizontal Date Rail ──
          _buildDateRail().guide('date_rail'),
        ],
      ),
    );
  }

  Widget _buildPortSelectorRow({
    required String label,
    required String portName,
    required String subtitle,
    required bool isOrigin,
  }) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOrigin ? colors.accent : Colors.transparent,
            border: Border.all(
              color: colors.accent,
              width: 2.5,
            ),
          ),
        ),
        const SizedBox(width: AppPalette.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelSmall?.copyWith(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: colors.text3,
                ),
              ),
              const SizedBox(height: 2),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: portName,
                  isDense: true,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: colors.text3),
                  borderRadius: BorderRadius.circular(AppPalette.radiusMd),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.text,
                  ),
                  dropdownColor: colors.surface,
                  items: _ports
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(p),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null && v != portName) {
                      setState(() {
                        if (isOrigin) {
                          _from = v;
                          _to = _ports.firstWhere((p) => p != v);
                        } else {
                          _to = v;
                          _from = _ports.firstWhere((p) => p != v);
                        }
                      });
                      _loadAvailableDates();
                      _search();
                    }
                  },
                ),
              ),
              Text(
                subtitle,
                style: text.bodySmall?.copyWith(
                  fontSize: 11,
                  color: colors.text3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _weekdayShort = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formatMonthYear(DateTime d) =>
      '${_monthNames[d.month - 1]} ${d.year}';

  String _formatDateDisplay(DateTime d) =>
      '${_weekdayShort[d.weekday - 1]}, ${_monthNames[d.month - 1]} ${d.day}';

  Widget _buildDateRail() {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final today = DateUtils.dateOnly(DateTime.now());

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: 21,
        separatorBuilder: (_, __) => const SizedBox(width: AppPalette.space8),
        itemBuilder: (context, i) {
          final day = today.add(Duration(days: i));
          final bool isToday = i == 0;
          final bool selected = DateUtils.isSameDay(day, _selectedDate);
          final bool hasTrips = _hasTripsOnDay(day);

          return Semantics(
            selected: selected,
            button: true,
            label:
                '${isToday ? "Today, " : ""}${_weekdayShort[day.weekday - 1]} ${day.day}',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppPalette.radiusMd),
              onTap: () {
                setState(() {
                  _selectedDate = day;
                  _focusedDay = day;
                });
                _search();
              },
              child: AnimatedContainer(
                duration: AppPalette.motionFast,
                curve: AppPalette.motionCurve,
                width: 60,
                decoration: BoxDecoration(
                  color: selected ? colors.accent : colors.surface2,
                  borderRadius: BorderRadius.circular(AppPalette.radiusMd),
                  border: Border.all(
                    color: selected
                        ? colors.accent
                        : (isToday ? colors.accent.withValues(alpha: 0.4) : colors.hairline),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isToday ? 'TODAY' : _weekdayShort[day.weekday - 1],
                      style: text.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: selected
                            ? AppPalette.white
                            : (isToday ? colors.accent : colors.text3),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.day}',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? AppPalette.white : colors.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasTrips
                            ? (selected ? AppPalette.white : colors.accent)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleResults() {
    return FutureBuilder<List<Schedule>>(
      future: _schedulesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is ApiException
              ? error.message
              : 'Unable to reach the port server. Please check your connection and tap retry.';

          return _buildErrorState(message);
        }

        final schedules = List<Schedule>.of(snapshot.data ?? []);
        if (_requestedTripId != null) {
          schedules.sort((a, b) => (a.id == _requestedTripId ? 0 : 1).compareTo(b.id == _requestedTripId ? 0 : 1));
        }
        if (schedules.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: schedules.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppPalette.space16),
          itemBuilder: (context, index) =>
              _buildScheduleCard(schedules[index]),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Column(
      children: [
        _ScheduleCardSkeleton(),
        SizedBox(height: AppPalette.space16),
        _ScheduleCardSkeleton(),
        SizedBox(height: AppPalette.space16),
        _ScheduleCardSkeleton(),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: AppEmptyState(
        icon: Icons.wifi_off_rounded,
        tone: AppPalette.danger,
        title: 'Connection interrupted',
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
        title: 'No scheduled sailings',
        caption:
            'There are no active trips sailing $_from → $_to on this date. You can check upcoming days or swap the route direction.',
        actionLabel: 'Swap route direction',
        onAction: _swapPorts,
      ),
    );
  }

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
                arguments: {'schedule': schedule, 'seatCount': _requestedSeats},
              )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Departure Time + Status Badge ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                schedule.time.isNotEmpty ? schedule.time : schedule.departureTime,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AppPalette.space12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.tint,
                  borderRadius: BorderRadius.circular(AppPalette.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      schedule.from,
                      style: text.labelSmall?.copyWith(
                        color: colors.onTint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 12, color: colors.onTint),
                    ),
                    Text(
                      schedule.to,
                      style: text.labelSmall?.copyWith(
                        color: colors.onTint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _buildStatusChip(schedule, soldOut),
            ],
          ),
          const SizedBox(height: AppPalette.space16),

          // ── Vessel Details & Real-Time Availability ──
          Row(
            children: [
              Icon(Icons.directions_boat_outlined,
                  size: 18, color: colors.text3),
              const SizedBox(width: AppPalette.space8),
              Expanded(
                child: Text(
                  schedule.boatName.isNotEmpty
                      ? schedule.boatName
                      : 'Commercial Passenger Lancha',
                  style: text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppPalette.space8),
              if (!soldOut)
                Text(
                  schedule.availableSeats < 5
                      ? 'Only ${schedule.availableSeats} seats left!'
                      : '${schedule.availableSeats} seats available',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: schedule.availableSeats < 5
                        ? AppPalette.danger
                        : colors.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const Divider(height: AppPalette.space24),

          // ── Bottom Action Row: Standard Fare + Booking Button ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REGULAR FARE',
                    style: text.labelSmall?.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.5,
                      color: colors.text3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FutureBuilder<RouteFare>(
                    future: _fareFuture,
                    builder: (context, snapshot) => Text(
                      snapshot.hasData ? '₱${snapshot.data!.regular.toStringAsFixed(2)}' : (snapshot.hasError ? 'See checkout' : 'Loading fare…'),
                      style: text.titleMedium?.copyWith(color: colors.accent, fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                ],
              ),
              if (canBook)
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(
                    BookingCheckoutScreen.routeName,
                    arguments: {'schedule': schedule, 'seatCount': _requestedSeats},
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppPalette.space16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppPalette.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Book Seats'),
                )
              else
                Text(
                  soldOut ? 'Trip Fully Booked' : 'Departure Passed',
                  style: text.labelMedium?.copyWith(color: colors.text3),
                ),
            ],
          ),
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
}

class _ScheduleCardSkeleton extends StatelessWidget {
  const _ScheduleCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      padding: EdgeInsets.all(AppPalette.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeleton(width: 110, height: 26),
              AppSkeleton(width: 80, height: 22, radius: AppPalette.radiusPill),
            ],
          ),
          SizedBox(height: AppPalette.space16),
          AppSkeleton(width: 200, height: 16),
          SizedBox(height: AppPalette.space20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppSkeleton(width: 70, height: 18),
              AppSkeleton(width: 100, height: 38, radius: AppPalette.radiusMd),
            ],
          ),
        ],
      ),
    );
  }
}
