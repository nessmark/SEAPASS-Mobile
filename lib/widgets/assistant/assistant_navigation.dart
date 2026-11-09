import 'package:flutter/foundation.dart';

import 'assistant_pages.dart';

/// A validated request from the assistant to open a passenger tab.
///
/// Only page names and booking prefill (date, route, trip, seat count) survive
/// parsing. Anything else the model sends, such as a payment or confirm flag,
/// is dropped, so the app can only ever open a screen and fill search fields.
/// The passenger still picks seats and taps Pay.
@immutable
class AssistantNavigationRequest {
  const AssistantNavigationRequest(this.page, this.prefill);

  final String page;
  final Map<String, dynamic> prefill;

  int get tabIndex => assistantTabIndex[page]!;

  static const _aliases = <String, String>{
    'home': 'trips',
    'trip': 'trips',
    'schedules': 'trips',
    'booking': 'bookings',
    'tickets': 'bookings',
    'my_bookings': 'bookings',
    'advisory': 'advisories',
    'notices': 'advisories',
    'account': 'profile',
    'my_account': 'profile',
  };

  /// Parses a host `navigate` event. Returns null for unknown or unsafe pages.
  static AssistantNavigationRequest? fromEvent(Map<dynamic, dynamic>? event, {DateTime? today}) {
    if (event == null) return null;
    final raw = (event['page'] ?? '').toString().trim().toLowerCase();
    final page = _aliases[raw] ?? raw;
    if (!assistantTabIndex.containsKey(page)) return null;
    final args = event['args'];
    final prefill = page == 'trips' && args is Map ? sanitizeBookingPrefill(args, today: today) : const <String, dynamic>{};
    return AssistantNavigationRequest(page, prefill);
  }

  /// Keeps only the booking search fields the trips screen understands.
  static Map<String, dynamic> sanitizeBookingPrefill(Map<dynamic, dynamic> args, {DateTime? today}) {
    final out = <String, dynamic>{};
    final now = today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);

    final date = args['date']?.toString() ?? '';
    final parsed = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ? DateTime.tryParse(date) : null;
    if (parsed != null && !parsed.isBefore(day)) out['date'] = date;

    final route = (args['route']?.toString() ?? '').trim();
    if (route.isNotEmpty && route.length <= 100) out['route'] = route;

    final trip = int.tryParse(args['trip_id']?.toString() ?? '');
    if (trip != null && trip > 0) out['trip_id'] = trip;

    final seats = int.tryParse(args['seats']?.toString() ?? '');
    if (seats != null && seats >= 1 && seats <= 10) out['seats'] = seats;
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is AssistantNavigationRequest && other.page == page && mapEquals(other.prefill, prefill);

  @override
  int get hashCode => Object.hash(page, Object.hashAllUnordered(prefill.entries.map((e) => '${e.key}=${e.value}')));
}

/// Hands a navigation request from a pushed screen (checkout, boarding pass)
/// to the passenger shell, which owns the tabs.
class AssistantNavigationBus {
  AssistantNavigationBus._();

  static final ValueNotifier<AssistantNavigationRequest?> pending = ValueNotifier(null);

  /// Returns and clears the pending request.
  static AssistantNavigationRequest? take() {
    final request = pending.value;
    pending.value = null;
    return request;
  }
}
