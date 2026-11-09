/// One registry for every passenger screen the assistant can see.
///
/// The assistant page context (what the model may point at) and the host
/// spotlight guide (what the passenger sees) both read from here, so a target
/// can never be offered to the model without a matching guide step.
library;

class AssistantGuideTarget {
  const AssistantGuideTarget(this.id, this.label, this.description, this.title, this.body);

  /// Matches a `.guide(id)` anchor on the rendered screen.
  final String id;

  /// Short name sent to the model.
  final String label;

  /// What the control does, sent to the model.
  final String description;

  /// Guide card title shown to the passenger.
  final String title;

  /// Guide card body shown to the passenger.
  final String body;

  Map<String, String> toContext() => {'id': id, 'label': label, 'description': description};
}

class AssistantPage {
  const AssistantPage(this.path, this.label, this.targets);

  /// Stable page key shared with the backend (`context.path`).
  final String path;

  /// Human page name sent as `context.label`.
  final String label;
  final List<AssistantGuideTarget> targets;
}

const assistantPages = <String, AssistantPage>{
  'trips': AssistantPage('trips', 'Trips', [
    AssistantGuideTarget('route_selector', 'Route & Port Selector', 'Choose origin and destination ports',
        'Choose your route', 'Choose your departure and destination ports. The swap button reverses the journey.'),
    AssistantGuideTarget('date_rail', 'Travel Date Rail', 'Select departure date across 21 days',
        'Pick a travel date', 'Tap a date to refresh departures. A dot marks dates with scheduled trips.'),
    AssistantGuideTarget('schedules_list', 'Scheduled Sailings', 'Departure times, boat names and available seats',
        'Review a sailing',
        'Check the boat, departure, available seats and live fare. Book Seats opens passenger details before you select seats or pay.'),
  ]),
  'bookings': AssistantPage('bookings', 'My Bookings', [
    AssistantGuideTarget('tabs', 'Booking Status Filter', 'Toggle between pending review and confirmed tickets',
        'Find your booking', 'Switch between bookings awaiting review and confirmed tickets.'),
    AssistantGuideTarget('booking_card', 'Booking Cards', 'Open boarding passes and view ticket QR codes',
        'Open your boarding pass', 'Open a confirmed booking to view the signed boarding QR for each passenger.'),
  ]),
  'advisories': AssistantPage('advisories', 'Advisories', [
    AssistantGuideTarget('advisories_list', 'Notice Board', 'Active port notices and sea condition bulletins',
        'Check port notices', 'Open a notice for its affected route, effective dates and full message. Pull down to refresh.'),
  ]),
  'profile': AssistantPage('profile', 'My Account', [
    AssistantGuideTarget('profile_card', 'Passenger Profile', 'View verified passenger details and contact number',
        'Your passenger details', 'These details identify your account and contact number.'),
    AssistantGuideTarget('account_settings', 'Account Settings', 'Update name, mobile number and change password',
        'Keep your details current', 'Edit profile saves to SeaPass. Changing your password requires your current password.'),
    AssistantGuideTarget('travel_history', 'Travel History', 'Archive of completed voyages',
        'Past voyages', 'Your completed trips appear here. A connection error is shown when history cannot load.'),
  ]),
  'checkout': AssistantPage('checkout', 'Booking Checkout', [
    AssistantGuideTarget('checkout_steps', 'Checkout Steps', 'Details, seats and payment steps of this booking',
        'Three short steps', 'Add passenger details, choose seats, then review and pay. Tap a finished step to go back to it.'),
    AssistantGuideTarget('passenger_types', 'Passenger Types', 'Number of regular, student and senior or PWD passengers',
        'Who is travelling', 'Set how many regular, student and senior or PWD passengers are booking. Discounts need a valid ID.'),
    AssistantGuideTarget('passenger_details', 'Passenger Details', 'Name and ID details for each passenger',
        'Passenger details', 'Fill in each passenger. Student, senior and PWD fares need the ID number and a photo of the ID.'),
    AssistantGuideTarget('fare_total', 'Fare Total', 'Live total fare and the Select Seats button',
        'Check the total', 'The total uses the live fare for this route. Select Seats moves to the seat map. Nothing is charged yet.'),
    AssistantGuideTarget('seat_map', 'Seat Map', 'Live seat map of the boat for choosing seats',
        'Choose seats', 'Pick a passenger, then tap a free seat. Taken seats cannot be chosen. Review & pay unlocks when every passenger has a seat.'),
    AssistantGuideTarget('payment_methods', 'Payment Method', 'How the passenger will pay',
        'Payment method', 'Choose how to pay. Payment opens only after you tap Pay.'),
    AssistantGuideTarget('fare_breakdown', 'Fare Breakdown', 'Itemized fare for each passenger type',
        'Fare breakdown', 'Check the fare for each passenger type before you pay.'),
    AssistantGuideTarget('confirm_pay', 'Pay Button', 'Button that reserves the seats and opens payment',
        'Pay', 'Pay reserves your seats and opens payment. The assistant never presses it for you.'),
  ]),
  'ticket': AssistantPage('ticket', 'Boarding Pass', [
    AssistantGuideTarget('trip_summary', 'Trip Summary', 'Route, boat, date, time and booking status',
        'Your trip', 'Check the route, boat, date and time. The status shows if staff still need to check a discount ID.'),
    AssistantGuideTarget('boarding_qr', 'Boarding QR', 'Signed QR code for each passenger',
        'Boarding QR', 'Show this QR to port staff when boarding. Each passenger has their own pass.'),
    AssistantGuideTarget('save_tickets', 'Save Tickets', 'Saves every pass to the phone gallery',
        'Keep a copy', 'Save the passes to your gallery so you can board even without signal.'),
  ]),
};

/// Pages a passenger can be sent to from the assistant, mapped to shell tabs.
const assistantTabIndex = <String, int>{'trips': 0, 'bookings': 1, 'advisories': 2, 'profile': 3};

AssistantPage? assistantPage(String path) => assistantPages[path];

/// Context targets for [path], limited to [mounted] anchor ids when any of
/// them are currently rendered. The backend only accepts highlight requests
/// for targets in this list, so it should name what is really on screen.
List<Map<String, String>> assistantTargetsFor(String path, {Iterable<String>? mounted}) {
  final page = assistantPages[path];
  if (page == null) return const [];
  final visible = mounted?.toSet();
  final onScreen = visible == null ? page.targets : page.targets.where((t) => visible.contains(t.id)).toList();
  final chosen = onScreen.isEmpty ? page.targets : onScreen;
  return chosen.map((t) => t.toContext()).toList();
}
