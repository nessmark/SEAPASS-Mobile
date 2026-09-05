class Schedule {
  final int id;
  final String from;
  final String to;
  final String departureTime;
  final String boatName;
  final String status;

  /// Human-readable travel date string, e.g. "2026-08-27".
  final String date;

  /// Formatted departure time for display, e.g. "10:30 AM".
  final String time;

  /// How many seats are still available for booking.
  final int availableSeats;

  /// Boat passenger capacity.
  final int capacity;

  /// Live seat map array from the backend.
  final List<dynamic> seatMap;

  /// Whether the trip is still in the future (Manila time) and can be booked.
  final bool isBookableInManila;

  Schedule({
    required this.id,
    required this.from,
    required this.to,
    required this.departureTime,
    required this.boatName,
    required this.status,
    this.date = '',
    this.time = '',
    this.availableSeats = 0,
    this.capacity = 40,
    this.seatMap = const [],
    this.isBookableInManila = true,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final rawTime =
        json['departure_time'] ?? json['departureTime'] ?? '';

    return Schedule(
      id: json['id'] ?? 0,
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      departureTime: rawTime.toString(),
      boatName: json['boat_name'] ?? json['boatName'] ?? '',
      status: json['status'] ?? '',
      date: json['date']?.toString() ??
          json['travel_date']?.toString() ??
          '',
      time: json['time']?.toString() ??
          json['formatted_time']?.toString() ??
          rawTime.toString(),
      availableSeats: (json['available_seats'] ??
              json['availableSeats'] ??
              0)
          .toInt(),
      capacity: (json['capacity'] ?? json['passenger_capacity'] ?? 40).toInt(),
      seatMap: (json['seat_map'] is List) ? json['seat_map'] as List : const [],
      isBookableInManila:
          json['is_bookable'] as bool? ?? true,
    );
  }

  bool matchesExactDate(DateTime date) {
    return true;
  }
}