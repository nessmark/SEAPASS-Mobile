import 'package:flutter/material.dart';

/// Represents a single passenger's details in the checkout flow.
class PassengerDetail {
  int index;
  final String category; // 'regular' | 'student' | 'senior'

  late final TextEditingController givenNamesController;
  late final TextEditingController lastNameController;
  late final TextEditingController idNumberController;

  String? assignedSeat;
  bool isExpanded = true;

  PassengerDetail({
    required this.index,
    required this.category,
    String initialGivenNames = '',
    String initialLastName = '',
    String initialIdNumber = '',
    this.assignedSeat,
    this.isExpanded = true,
  }) {
    givenNamesController = TextEditingController(text: initialGivenNames);
    lastNameController = TextEditingController(text: initialLastName);
    idNumberController = TextEditingController(text: initialIdNumber);
  }

  /// Creates a deep copy with freshly instantiated TextEditingControllers.
  PassengerDetail deepClone({
    int? newIndex,
    String? newCategory,
    bool? newIsExpanded,
  }) {
    return PassengerDetail(
      index: newIndex ?? index,
      category: newCategory ?? category,
      initialGivenNames: givenNamesController.text,
      initialLastName: lastNameController.text,
      initialIdNumber: idNumberController.text,
      assignedSeat: assignedSeat,
      isExpanded: newIsExpanded ?? isExpanded,
    );
  }

  String get categoryLabel {
    switch (category) {
      case 'student':
        return 'Student (Discounted)';
      case 'senior':
        return 'Senior Citizen / PWD (20% Off)';
      default:
        return 'Regular';
    }
  }

  String get fullName {
    final first = givenNamesController.text.trim();
    final last = lastNameController.text.trim();
    if (first.isEmpty && last.isEmpty) return 'Passenger $index';
    if (last.isEmpty) return first;
    return '$first $last';
  }

  bool get isComplete {
    final first = givenNamesController.text.trim();
    final last = lastNameController.text.trim();
    final hasNames = first.isNotEmpty && last.isNotEmpty;
    final hasIdIfDiscounted = (category == 'regular') || idNumberController.text.trim().isNotEmpty;
    return hasNames && hasIdIfDiscounted;
  }

  void dispose() {
    givenNamesController.dispose();
    lastNameController.dispose();
    idNumberController.dispose();
  }
}

/// Represents the primary booking contact person details.
class ContactDetails {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  String countryCode = '+63';

  ContactDetails({
    String initialName = '',
    String initialEmail = '',
    String initialPhone = '',
    this.countryCode = '+63',
  })  : nameController = TextEditingController(text: initialName),
        emailController = TextEditingController(text: initialEmail),
        phoneController = TextEditingController(text: initialPhone);

  bool get isComplete {
    return nameController.text.trim().isNotEmpty &&
        emailController.text.trim().isNotEmpty &&
        phoneController.text.trim().isNotEmpty;
  }

  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }
}

/// Represents an individual seat on the vessel layout grid with standard row-column coordinates.
class VesselSeat {
  final String seatNumber; // e.g. "1A", "1B"
  final int row; // 1 to 8+
  final String column; // 'A', 'B', 'C', 'D', 'E'
  final String status; // 'available' | 'selected' | 'booked'
  final bool isBooked;
  int? assignedPassengerIndex;

  VesselSeat({
    required this.seatNumber,
    required this.row,
    required this.column,
    this.status = 'available',
    this.isBooked = false,
    this.assignedPassengerIndex,
  });

  String get code => seatNumber;
  String get displayLabel => 'Seat $seatNumber';
  bool get isAvailable => !isBooked && status != 'booked';
  bool get isSelected => assignedPassengerIndex != null || status == 'selected';

  Map<String, dynamic> toJson() => {
        'seat_number': seatNumber,
        'row': row,
        'column': column,
        'status': isBooked ? 'booked' : (isSelected ? 'selected' : 'available'),
      };

  factory VesselSeat.fromJson(Map<String, dynamic> json) {
    final seatNum = json['seat_number']?.toString() ?? '';
    final booked = json['booked'] == true || json['status'] == 'booked';
    return VesselSeat(
      seatNumber: seatNum,
      row: (json['row'] is int)
          ? json['row']
          : int.tryParse(json['row']?.toString() ?? '1') ?? 1,
      column: json['column']?.toString() ?? '',
      status: booked ? 'booked' : (json['status']?.toString() ?? 'available'),
      isBooked: booked,
    );
  }
}

/// Represents a payment method option for Step 3.
class PaymentMethodOption {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final String badge;
  final double discount;

  const PaymentMethodOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    this.badge = '',
    this.discount = 0.0,
  });
}
