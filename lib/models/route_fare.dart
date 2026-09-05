class RouteFare {
  final int id;
  final String route;

  /// Base / regular passenger fare.
  final double regular;

  /// Student-discounted fare.
  final double student;

  /// Senior citizen / PWD fare.
  final double senior;

  final String? from;
  final String? to;

  const RouteFare({
    this.id = 0,
    this.route = '',
    this.regular = 0,
    this.student = 0,
    this.senior = 0,
    this.from,
    this.to,
  });

  /// Convenience getter so legacy code that reads `.price` still works.
  double get price => regular;

  factory RouteFare.fromJson(Map<String, dynamic> json) {
    // Support both new per-type fields and the legacy single `price` field.
    final basePrice = (json['price'] ?? 0).toDouble();
    return RouteFare(
      id: json['id'] ?? 0,
      route: json['route'] ?? '',
      regular: (json['regular_fare'] ?? json['regular'] ?? basePrice).toDouble(),
      student: (json['student_fare'] ?? json['student'] ?? basePrice).toDouble(),
      senior: (json['senior_fare'] ?? json['senior'] ?? basePrice).toDouble(),
      from: json['from']?.toString(),
      to: json['to']?.toString(),
    );
  }
}

