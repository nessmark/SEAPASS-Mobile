import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/passenger_booking_models.dart';
import '../../../models/route_fare.dart';
import '../../../models/schedule.dart';
import '../../../widgets/app_palette.dart';

/// Step 1 of the booking checkout flow:
/// Displays the trip summary, passenger counters, and dynamic passenger details form cards.
class CheckoutStepDetails extends StatelessWidget {
  const CheckoutStepDetails({
    super.key,
    required this.schedule,
    required this.fare,
    required this.regularCount,
    required this.studentCount,
    required this.seniorCount,
    required this.totalSeats,
    required this.totalPrice,
    required this.passengers,
    required this.onIncrementCategory,
    required this.onDecrementCategory,
    required this.onProceedToSeats,
    required this.onPassengerFormUpdated,
  });

  final Schedule schedule;
  final RouteFare fare;
  final int regularCount;
  final int studentCount;
  final int seniorCount;
  final int totalSeats;
  final double totalPrice;
  final List<PassengerDetail> passengers;

  final void Function(String type) onIncrementCategory;
  final void Function(String type) onDecrementCategory;
  final VoidCallback onProceedToSeats;
  final VoidCallback onPassengerFormUpdated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trip Route & Vessel Summary Card
        _buildTripSummaryCard(),
        const SizedBox(height: 18),

        // Seat Category Counter Selectors
        Text(
          'Select Seats & Passenger Types',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppPalette.darkText,
              ),
        ),
        const SizedBox(height: 10),

        _buildCounterRow(
          label: 'Regular',
          unitPrice: fare.regular,
          count: regularCount,
          onDecrement: () => onDecrementCategory('regular'),
          onIncrement: () => onIncrementCategory('regular'),
        ),
        const SizedBox(height: 8),

        _buildCounterRow(
          label: 'Student',
          badgeText: 'Discounted',
          unitPrice: fare.student,
          count: studentCount,
          onDecrement: () => onDecrementCategory('student'),
          onIncrement: () => onIncrementCategory('student'),
        ),
        const SizedBox(height: 8),

        _buildCounterRow(
          label: 'Senior Citizen / PWD',
          badgeText: '20% Off',
          unitPrice: fare.senior,
          count: seniorCount,
          onDecrement: () => onDecrementCategory('senior'),
          onIncrement: () => onIncrementCategory('senior'),
        ),
        const SizedBox(height: 22),

        // Dynamic Passenger Detail Cards
        Text(
          'Passenger Details (${passengers.length} Total)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppPalette.darkText,
              ),
        ),
        const SizedBox(height: 10),

        ...passengers.map((p) => _buildPassengerAccordionCard(context, p)),

        const SizedBox(height: 14),

        // Sticky Bottom Price & Action
        _buildStep1BottomBar(),
      ],
    );
  }

  Widget _buildTripSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${schedule.from} → ${schedule.to}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.darkText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.mintGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${schedule.availableSeats} seats left',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.mintGreen,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppPalette.mintGreen),
              const SizedBox(width: 8),
              Text(
                'Travel Date: ${schedule.date.isNotEmpty ? schedule.date : 'Selected Date'}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: AppPalette.mintGreen),
              const SizedBox(width: 8),
              Text(
                'Departure Time: ${schedule.time}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.directions_boat_outlined, size: 16, color: AppPalette.mintGreen),
              const SizedBox(width: 8),
              Text(
                'Vessel / Boat: ${schedule.boatName}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterRow({
    required String label,
    required double unitPrice,
    required int count,
    String? badgeText,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0
              ? AppPalette.mintGreen.withValues(alpha: 0.5)
              : Colors.grey.shade300,
          width: count > 0 ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppPalette.darkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppPalette.mintGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.mintGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${unitPrice.toStringAsFixed(2)} / passenger',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: count > 0 ? onDecrement : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppPalette.mintGreen,
                disabledColor: Colors.grey.shade300,
                iconSize: 24,
              ),
              SizedBox(
                width: 20,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline),
                color: AppPalette.mintGreen,
                iconSize: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerAccordionCard(BuildContext context, PassengerDetail passenger) {
    final bool isCompleted = passenger.isComplete;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? AppPalette.mintGreen.withValues(alpha: 0.5)
              : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () {
              passenger.isExpanded = !passenger.isExpanded;
              onPassengerFormUpdated();
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Passenger ${passenger.index}: ${passenger.categoryLabel}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppPalette.darkText,
                          ),
                        ),
                        if (passenger.fullName != 'Passenger ${passenger.index}') ...[
                          const SizedBox(height: 2),
                          Text(
                            passenger.fullName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppPalette.mintGreen.withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'Not completed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? AppPalette.mintGreen : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Icon(
                    passenger.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),

          // Accordion Body Form
          if (passenger.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Given Names
                  TextField(
                    controller: passenger.givenNamesController,
                    onChanged: (_) => onPassengerFormUpdated(),
                    decoration: InputDecoration(
                      labelText: 'Given names (including suffix) *',
                      hintText: 'e.g. Juan Jr.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Last Name
                  TextField(
                    controller: passenger.lastNameController,
                    onChanged: (_) => onPassengerFormUpdated(),
                    decoration: InputDecoration(
                      labelText: 'Last name (surname) *',
                      hintText: 'e.g. Dela Cruz',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  // Discount / ID Verification Image Picker if Student or Senior/PWD
                  if (passenger.category != 'regular') ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppPalette.mintGreen.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (passenger.idPhotoPath != null && passenger.idPhotoPath!.isNotEmpty)
                              ? AppPalette.mintGreen
                              : AppPalette.mintGreen.withValues(alpha: 0.4),
                          width: (passenger.idPhotoPath != null && passenger.idPhotoPath!.isNotEmpty) ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 18,
                                color: AppPalette.mintGreen,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  passenger.category == 'student'
                                      ? 'Student Discount ID Verification *'
                                      : 'Senior Citizen / PWD ID Verification *',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppPalette.mintGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please attach a clear photo of your valid ID card to verify discount eligibility.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (passenger.idPhotoPath == null || passenger.idPhotoPath!.isEmpty) ...[
                            // Unattached: Upload action box
                            InkWell(
                              onTap: () => _showImageSourceSheet(context, passenger),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 32,
                                      color: AppPalette.mintGreen,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Upload Valid ID Photo *',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppPalette.darkText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to take a photo or select from gallery',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            // Attached: Preview thumbnail with replace/delete actions
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(passenger.idPhotoPath!),
                                      width: 80,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 80,
                                        height: 60,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppPalette.mintGreen.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded, size: 13, color: AppPalette.mintGreen),
                                              SizedBox(width: 4),
                                              Text(
                                                'ID Photo Attached',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppPalette.mintGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () => _showImageSourceSheet(context, passenger),
                                          child: const Text(
                                            'Change / Retake photo',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppPalette.mintGreen,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                    tooltip: 'Remove photo',
                                    onPressed: () {
                                      passenger.idPhotoPath = null;
                                      onPassengerFormUpdated();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        passenger.isExpanded = false;
                        final nextIndex = passenger.index;
                        if (nextIndex < passengers.length) {
                          passengers[nextIndex].isExpanded = true;
                        }
                        onPassengerFormUpdated();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: AppPalette.darkText,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      child: const Text('Save & continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep1BottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.mintGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL PRICE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '$totalSeats Seat${totalSeats == 1 ? '' : 's'} Selected',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.darkText,
                    ),
                  ),
                ],
              ),
              Text(
                '₱${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.mintGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onProceedToSeats,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.mintGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'SELECT SEATS →',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, PassengerDetail passenger, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        passenger.idPhotoPath = picked.path;
        onPassengerFormUpdated();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick photo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet(BuildContext context, PassengerDetail passenger) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Upload Discount ID Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.darkText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select the source for Passenger ${passenger.index}\'s ID photo',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.mintGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: AppPalette.mintGreen),
                ),
                title: const Text(
                  'Take Photo (Camera)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Capture a clear picture of your physical ID card',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(context, passenger, ImageSource.camera);
                },
              ),
              const Divider(indent: 64, endIndent: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.mintGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppPalette.mintGreen),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Select a photo or scan already saved on your phone',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(context, passenger, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
