import 'dart:convert';

class PassengerTicketInfo {
  final String id; // e.g. "P1", "P2"
  final String name; // e.g. "Jembo Magbanua", "Maria Santos"
  final String seat; // e.g. "4D", "4E"
  final String category; // e.g. "regular", "student", "senior"
  final double individualFare; // e.g. 1060.00, 848.00

  const PassengerTicketInfo({
    required this.id,
    required this.name,
    required this.seat,
    this.category = 'Regular',
    double? individualFare,
    double? fare,
  }) : individualFare = individualFare ?? fare ?? 0.0;

  /// Backward-compatible alias for `.fare`
  double get fare => individualFare;

  /// User-friendly label for fare category
  String get categoryDisplay {
    final cat = category.toLowerCase().trim();
    if (cat == 'student') {
      return 'Student (Discounted)';
    } else if (cat == 'senior' || cat == 'pwd' || cat.contains('senior')) {
      return 'Senior Citizen / PWD (20% Off)';
    } else if (cat == 'child') {
      return 'Child (50% Off)';
    }
    return 'Regular';
  }

  /// Calculates the dynamic individual fare according to the category.
  static double getIndividualFareByCategory({
    required String category,
    required double regularFare,
    double? studentFare,
    double? seniorPwdFare,
  }) {
    final cat = category.toLowerCase().trim();
    switch (cat) {
      case 'student':
        return (studentFare != null && studentFare > 0)
            ? studentFare
            : (regularFare * 0.80);
      case 'senior':
      case 'senior citizen':
      case 'pwd':
        return (seniorPwdFare != null && seniorPwdFare > 0)
            ? seniorPwdFare
            : (regularFare * 0.80);
      case 'child':
        return regularFare * 0.50;
      case 'regular':
      default:
        return regularFare;
    }
  }

  Map<String, dynamic> toQrPayload({
    required String bookingRef,
    required String vessel,
  }) {
    return {
      'booking_ref': bookingRef,
      'passenger_id': id,
      'passenger_name': name,
      'seat': seat,
      'vessel': vessel,
      'category': category,
      'individual_fare': individualFare,
    };
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.referenceNumber,
    required this.passengerName,
    required this.route,
    required this.date,
    required this.time,
    required this.boatName,
    required this.seatCount,
    this.seatNumbers = const [],
    this.seatBreakdown,
    required this.totalPrice,
    required this.status,
    this.qrCode,
    this.notes,
    this.showViewTicket = false,
  });

  final String id;
  final String referenceNumber;
  final String passengerName;
  final String route;
  final String date;
  final String time;
  final String boatName;
  final int seatCount;
  final List<String> seatNumbers;
  final List<dynamic>? seatBreakdown;
  final double totalPrice;
  final String status;
  final String? qrCode;
  final String? notes;
  final bool showViewTicket;

  bool get isConfirmed => status.toLowerCase() == 'confirmed';
  bool get isPending =>
      status.toLowerCase() == 'pending' ||
      status.toLowerCase() == 'to_be_confirmed';

  /// Returns the sum of all individual passenger fares.
  double get calculatedTotalFare {
    final tickets = passengerTickets;
    if (tickets.isEmpty) return totalPrice;
    return tickets.fold<double>(0.0, (sum, t) => sum + t.individualFare);
  }

  /// Generates category-accurate [PassengerTicketInfo] instances for this booking.
  /// Dynamically computes distinct individual fares for Regular, Student, Senior, and Child.
  List<PassengerTicketInfo> get passengerTickets {
    final List<PassengerTicketInfo> tickets = [];

    // 1. First priority: Check if seatBreakdown is present from purchase snapshot
    if (seatBreakdown != null && seatBreakdown!.isNotEmpty) {
      for (int i = 0; i < seatBreakdown!.length; i++) {
        final item = seatBreakdown![i];
        if (item is Map) {
          final pId = item['passenger_id']?.toString() ?? 'P${i + 1}';
          final pName =
              item['passenger_name']?.toString() ?? 'Passenger ${i + 1}';
          final pSeat = item['seat']?.toString() ??
              (seatNumbers.length > i ? seatNumbers[i] : '4D');
          final pCat = item['category']?.toString() ?? 'regular';
          double pFare = 0.0;
          if (item['individual_fare'] is num) {
            pFare = (item['individual_fare'] as num).toDouble();
          } else if (item['fare'] is num) {
            pFare = (item['fare'] as num).toDouble();
          }

          if (pFare <= 0) {
            pFare = PassengerTicketInfo.getIndividualFareByCategory(
              category: pCat,
              regularFare: 1060.00,
            );
          }

          tickets.add(PassengerTicketInfo(
            id: pId,
            name: pName.isNotEmpty ? pName : passengerName,
            seat: pSeat,
            category: pCat,
            individualFare: pFare,
          ));
        }
      }
      if (tickets.isNotEmpty) return tickets;
    }

    // 2. Second priority: Parse from booking notes
    // Formats supported:
    // - Seats: Name (Seat #4D - Regular - ₱1,060.00), Name 2 (Seat #4E - Student - ₱848.00)
    // - Seats: Name (Seat #4D - Regular), Name 2 (Seat #4E - Student)
    if (notes != null && notes!.isNotEmpty) {
      final regExp = RegExp(
        r"([A-Za-z0-9 .\-'\u00C0-\u017F]+?)\s*\(Seat #?([A-Za-z0-9\-]+)(?:\s*-\s*([A-Za-z0-9 ]+?))?(?:\s*-\s*₱?([0-9.,]+))?\)",
        caseSensitive: false,
      );
      final matches = regExp.allMatches(notes!);
      if (matches.isNotEmpty) {
        final List<Map<String, dynamic>> parsedList = [];
        for (final m in matches) {
          final pName = m.group(1)?.trim() ?? passengerName;
          final pSeat = m.group(2)?.trim() ?? '4D';
          final pCat = m.group(3)?.trim() ?? 'Regular';
          double? explicitPrice;
          if (m.group(4) != null) {
            final rawPrice = m.group(4)!.replaceAll(',', '').trim();
            explicitPrice = double.tryParse(rawPrice);
          }

          parsedList.add({
            'name': pName,
            'seat': pSeat,
            'category': pCat,
            'explicitPrice': explicitPrice,
          });
        }

        // Determine base rate for category calculations
        double baseRate = 1060.00;
        final hasExplicit = parsedList.any((p) =>
            p['explicitPrice'] != null && (p['explicitPrice'] as double) > 0);

        if (!hasExplicit && totalPrice > 0) {
          double totalWeight = 0.0;
          for (final p in parsedList) {
            final cat = (p['category'] as String).toLowerCase();
            if (cat == 'student' || cat == 'senior' || cat == 'pwd') {
              totalWeight += 0.80;
            } else if (cat == 'child') {
              totalWeight += 0.50;
            } else {
              totalWeight += 1.0;
            }
          }
          if (totalWeight > 0) {
            baseRate = totalPrice / totalWeight;
            // Align to standard tariff if within reasonable range of 1060
            if ((baseRate - 1060.00).abs() < 60) {
              baseRate = 1060.00;
            }
          }
        }

        int idx = 1;
        for (final p in parsedList) {
          final pCat = p['category'] as String;
          double pFare;
          if (p['explicitPrice'] != null &&
              (p['explicitPrice'] as double) > 0) {
            pFare = p['explicitPrice'] as double;
          } else {
            pFare = PassengerTicketInfo.getIndividualFareByCategory(
              category: pCat,
              regularFare: baseRate,
            );
          }

          final pSeat = (p['seat'] as String).isNotEmpty
              ? (p['seat'] as String)
              : (seatNumbers.length >= idx ? seatNumbers[idx - 1] : '4D');

          tickets.add(PassengerTicketInfo(
            id: 'P$idx',
            name: (p['name'] as String).isNotEmpty
                ? (p['name'] as String)
                : passengerName,
            seat: pSeat,
            category: pCat,
            individualFare: pFare,
          ));
          idx++;
        }
        return tickets;
      }
    }

    // 3. Fallback: Multi-seat booking without passenger notes
    final count = seatNumbers.isNotEmpty
        ? seatNumbers.length
        : (seatCount > 1 ? seatCount : 1);
    final baseFare = totalPrice > 0 ? (totalPrice / count) : 1060.00;

    if (count > 1) {
      for (int i = 0; i < count; i++) {
        final pId = 'P${i + 1}';
        final pName = i == 0 ? passengerName : 'Passenger ${i + 1}';
        final pSeat = seatNumbers.length > i ? seatNumbers[i] : '${i + 1}A';
        tickets.add(PassengerTicketInfo(
          id: pId,
          name: pName,
          seat: pSeat,
          category: 'Regular',
          individualFare: baseFare,
        ));
      }
      return tickets;
    }

    // 4. Single passenger fallback
    final pSeat = seatNumbers.isNotEmpty ? seatNumbers.first : '4D';
    tickets.add(PassengerTicketInfo(
      id: 'P1',
      name: passengerName.isNotEmpty ? passengerName : 'Passenger',
      seat: pSeat,
      category: 'Regular',
      individualFare: totalPrice > 0 ? totalPrice : 1060.00,
    ));

    return tickets;
  }

  factory Booking.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? 'pending').toString().toLowerCase();
    String normalizedStatus = 'Pending';
    if (rawStatus == 'confirmed') normalizedStatus = 'Confirmed';
    if (rawStatus == 'cancelled') normalizedStatus = 'Cancelled';

    List<String> seatsList = [];
    if (json['seat_numbers'] is List) {
      seatsList = (json['seat_numbers'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty && e != 'null')
          .toList();
    } else if (json['seat_numbers'] is String &&
        (json['seat_numbers'] as String).trim().isNotEmpty) {
      final str = (json['seat_numbers'] as String).trim();
      if (str.startsWith('[') && str.endsWith(']')) {
        try {
          final decoded = jsonDecode(str);
          if (decoded is List) {
            seatsList = decoded
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty && e != 'null')
                .toList();
          }
        } catch (_) {}
      } else {
        seatsList = str
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && e != 'null')
            .toList();
      }
    }

    // Fallback: extract seat assignment from notes if seat_numbers is empty
    if (seatsList.isEmpty && json['notes'] != null) {
      final notesStr = json['notes'].toString();
      final regExp = RegExp(
          r'Seat #?([A-Za-z0-9\- ]+?)(?: -|\)|,|$)',
          caseSensitive: false);
      final matches = regExp.allMatches(notesStr);
      for (final match in matches) {
        final val = match.group(1)?.trim();
        if (val != null && val.isNotEmpty && !seatsList.contains(val)) {
          seatsList.add(val);
        }
      }
    }

    return Booking(
      id: json['id']?.toString() ?? '',
      referenceNumber: json['reference_number']?.toString() ??
          (json['id'] != null ? 'SP${json['id']}' : 'SP101'),
      passengerName: json['passenger_name']?.toString() ?? 'Passenger',
      route: json['route']?.toString() ?? 'Surigao → San Jose(Dinagat)',
      date: json['trip_date']?.toString() ?? '',
      time: json['departure_time_slot']?.toString() ?? '',
      boatName: json['boat_name']?.toString() ?? 'BANCKA',
      seatCount: json['seat_count'] is int
          ? json['seat_count'] as int
          : seatsList.isNotEmpty
              ? seatsList.length
              : 1,
      seatNumbers: seatsList,
      seatBreakdown: json['seat_breakdown'] is List
          ? json['seat_breakdown'] as List
          : null,
      totalPrice: (json['amount_collected'] is num)
          ? (json['amount_collected'] as num).toDouble()
          : 0.0,
      status: normalizedStatus,
      qrCode: json['qr_code']?.toString(),
      notes: json['notes']?.toString(),
      showViewTicket: normalizedStatus == 'Confirmed',
    );
  }
}
