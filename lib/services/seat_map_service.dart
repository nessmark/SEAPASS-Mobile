import 'dart:async';

import 'package:flutter/foundation.dart';

import 'passenger_data_service.dart';

/// Service responsible for fetching and synchronizing trip seat map data.
///
/// Features:
/// - Stream-based reactive architecture (WebSocket-ready for future real-time upgrades)
/// - Adaptive polling: 15s default interval; slows to 30s after 2 minutes of idle time
/// - Explicit pause/resume lifecycle guards to eliminate background polling
/// - Manual refresh support with a loading state notifier
class SeatMapService {
  SeatMapService({PassengerDataService? dataService})
      : _dataService = dataService ?? const PassengerDataService();

  final PassengerDataService _dataService;

  final StreamController<List<dynamic>> _seatMapController =
      StreamController<List<dynamic>>.broadcast();

  /// Reactive stream of seat map updates.
  /// Subscribed widgets update whenever new data arrives.
  Stream<List<dynamic>> get seatMapStream => _seatMapController.stream;

  /// Notifier exposing whether an on-demand manual refresh is in flight.
  final ValueNotifier<bool> isRefreshing = ValueNotifier<bool>(false);

  int? _activeScheduleId;
  Timer? _pollTimer;
  DateTime? _lastInteractionTime;
  bool _isPollingPaused = false;

  /// Base active polling interval (15 seconds).
  static const Duration _activeInterval = Duration(seconds: 15);

  /// Backoff interval when idle for > 2 minutes (30 seconds).
  static const Duration _idleInterval = Duration(seconds: 30);

  /// Threshold of inactivity before backing off (2 minutes).
  static const Duration _idleThreshold = Duration(minutes: 2);

  /// Starts polling for the specified trip schedule.
  void startPolling(int scheduleId) {
    if (_activeScheduleId == scheduleId && _pollTimer != null && !_isPollingPaused) {
      return;
    }

    _activeScheduleId = scheduleId;
    _isPollingPaused = false;
    _lastInteractionTime = DateTime.now();

    // Initial silent fetch
    fetchSeatMap(silent: true);

    _scheduleNextPoll();
  }

  /// Records user interaction (e.g. seat tap) to reset the adaptive backoff timer.
  void recordInteraction() {
    _lastInteractionTime = DateTime.now();
  }

  /// Schedules the next polling tick based on adaptive user activity.
  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    if (_activeScheduleId == null || _isPollingPaused) return;

    final Duration interval = _determineInterval();

    _pollTimer = Timer(interval, () async {
      if (_activeScheduleId != null && !_isPollingPaused) {
        await fetchSeatMap(silent: true);
        _scheduleNextPoll();
      }
    });
  }

  /// Determines the adaptive interval: 15s if active, 30s if idle > 2 minutes.
  Duration _determineInterval() {
    if (_lastInteractionTime == null) return _activeInterval;
    final idleDuration = DateTime.now().difference(_lastInteractionTime!);
    return idleDuration >= _idleThreshold ? _idleInterval : _activeInterval;
  }

  /// Fetches the live seat map from the API and emits it to the stream.
  Future<void> fetchSeatMap({bool silent = true}) async {
    final scheduleId = _activeScheduleId;
    if (scheduleId == null) return;

    try {
      final data = await _dataService.fetchTripSeatMap(scheduleId);
      if (!_seatMapController.isClosed && data.isNotEmpty && data['seat_map'] is List) {
        _seatMapController.add(data['seat_map'] as List);
      }
    } catch (_) {
      // Retain existing map on network hiccups
    }
  }

  /// Triggers an immediate manual refresh and updates [isRefreshing].
  Future<void> manualRefresh() async {
    if (_activeScheduleId == null) return;
    recordInteraction();
    isRefreshing.value = true;
    try {
      await fetchSeatMap(silent: false);
    } finally {
      isRefreshing.value = false;
    }
    // Re-schedule next tick from this refresh point
    _scheduleNextPoll();
  }

  /// Pauses polling when the app is backgrounded or leaves Step 2.
  void pausePolling() {
    _isPollingPaused = true;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Resumes polling when the app returns to foreground while on Step 2.
  void resumePolling() {
    if (_activeScheduleId == null) return;
    _isPollingPaused = false;
    _lastInteractionTime = DateTime.now();
    fetchSeatMap(silent: true);
    _scheduleNextPoll();
  }

  /// Completely stops polling.
  void stopPolling() {
    _activeScheduleId = null;
    _isPollingPaused = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Disposes of timers, notifiers, and stream controllers.
  void dispose() {
    stopPolling();
    isRefreshing.dispose();
    _seatMapController.close();
  }
}
