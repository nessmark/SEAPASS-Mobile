import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/passenger_booking_models.dart';
import '../../../models/route_fare.dart';
import '../../../models/schedule.dart';
import '../../../widgets/app_palette.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/status_chip.dart';

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
        _buildTripSummaryCard(context),
        const SizedBox(height: 18),

        // Seat Category Counter Selectors
        const SectionHeader('Select Seats & Passenger Types'),

        _buildCounterRow(context, 
          label: 'Regular',
          unitPrice: fare.regular,
          count: regularCount,
          onDecrement: () => onDecrementCategory('regular'),
          onIncrement: () => onIncrementCategory('regular'),
        ),
        const SizedBox(height: 8),

        _buildCounterRow(context, 
          label: 'Student',
          badgeText: 'Discounted',
          unitPrice: fare.student,
          count: studentCount,
          onDecrement: () => onDecrementCategory('student'),
          onIncrement: () => onIncrementCategory('student'),
        ),
        const SizedBox(height: 8),

        _buildCounterRow(context, 
          label: 'Senior Citizen / PWD',
          badgeText: '20% Off',
          unitPrice: fare.senior,
          count: seniorCount,
          onDecrement: () => onDecrementCategory('senior'),
          onIncrement: () => onIncrementCategory('senior'),
        ),
        const SizedBox(height: 22),

        // Dynamic Passenger Detail Cards
        SectionHeader('Passenger Details (${passengers.length} Total)'),

        ...passengers.map((p) => _buildPassengerAccordionCard(context, p)),

        const SizedBox(height: 14),

        // Sticky Bottom Price & Action
        _buildStep1BottomBar(context),
      ],
    );
  }

  Widget _buildTripSummaryCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${schedule.from} → ${schedule.to}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 12),
              StatusChip(label: '${schedule.availableSeats} seats left'),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: AppColors.of(context).accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Travel Date: ${schedule.date.isNotEmpty ? schedule.date : 'Selected Date'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 16, color: AppColors.of(context).accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Departure Time: ${schedule.time}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.directions_boat_outlined,
                  size: 16, color: AppColors.of(context).accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vessel / Boat: ${schedule.boatName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterRow(BuildContext context, {
    required String label,
    required double unitPrice,
    required int count,
    String? badgeText,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Flexible(child: StatusChip(label: badgeText)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${unitPrice.toStringAsFixed(2)} / passenger',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: count > 0 ? onDecrement : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.of(context).accent,
                disabledColor: AppColors.of(context).text3,
                iconSize: 24,
              ),
              SizedBox(
                width: 24,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.of(context).accent,
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

    return AppCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () {
              passenger.isExpanded = !passenger.isExpanded;
              onPassengerFormUpdated();
            },
            borderRadius: BorderRadius.circular(AppPalette.radiusLg),
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
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (passenger.fullName != 'Passenger ${passenger.index}') ...[
                          const SizedBox(height: 2),
                          Text(
                            passenger.fullName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status Chip
                  StatusChip(
                    label: isCompleted ? 'Completed' : 'Not completed',
                    tone: isCompleted ? StatusTone.success : StatusTone.warning,
                    icon: isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.edit_outlined,
                  ),
                  const SizedBox(width: 8),

                  Icon(
                    passenger.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.of(context).text2,
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
                    decoration: const InputDecoration(
                      labelText: 'Given names (including suffix) *',
                      hintText: 'e.g. Juan Jr.',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Last Name
                  TextField(
                    controller: passenger.lastNameController,
                    onChanged: (_) => onPassengerFormUpdated(),
                    decoration: const InputDecoration(
                      labelText: 'Last name (surname) *',
                      hintText: 'e.g. Dela Cruz',
                    ),
                  ),

                  // Discount / ID Verification Image Picker if Student or Senior/PWD
                  if (passenger.category != 'regular') ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.of(context).tint,
                        borderRadius:
                            BorderRadius.circular(AppPalette.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 18,
                                color: AppColors.of(context).onTint,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  passenger.category == 'student'
                                      ? 'Student Discount ID Verification *'
                                      : 'Senior Citizen / PWD ID Verification *',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                          color: AppColors.of(context).onTint),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please attach a clear photo of your valid ID card to verify discount eligibility.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          if (passenger.idPhotoPath == null || passenger.idPhotoPath!.isEmpty) ...[
                            // Unattached: Upload action box
                            InkWell(
                              onTap: () => _showImageSourceSheet(context, passenger),
                              borderRadius:
                                  BorderRadius.circular(AppPalette.radiusSm),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.of(context).surface,
                                  borderRadius: BorderRadius.circular(
                                      AppPalette.radiusSm),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 32,
                                      color: AppColors.of(context).accent,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload Valid ID Photo *',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to take a photo or select from gallery',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            // Attached: Preview thumbnail with replace/delete actions
                            AppCard(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        AppPalette.radiusSm),
                                    child: Image.file(
                                      File(passenger.idPhotoPath!),
                                      width: 80,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 80,
                                        height: 60,
                                        color: AppColors.of(context).surface2,
                                        child: Icon(Icons.broken_image_outlined, color: AppColors.of(context).text3),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const StatusChip(
                                          label: 'ID Photo Attached',
                                          tone: StatusTone.success,
                                          icon: Icons.check_circle_rounded,
                                        ),
                                        const SizedBox(height: 6),
                                        TextButton(
                                          onPressed: () => _showImageSourceSheet(
                                              context, passenger),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 36),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            textStyle: Theme.of(context)
                                                .textTheme
                                                .labelMedium,
                                          ),
                                          child: const Text(
                                              'Change / Retake photo'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppPalette.danger),
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
                    child: FilledButton.tonal(
                      onPressed: () {
                        passenger.isExpanded = false;
                        final nextIndex = passenger.index;
                        if (nextIndex < passengers.length) {
                          passengers[nextIndex].isExpanded = true;
                        }
                        onPassengerFormUpdated();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.of(context).tint,
                        foregroundColor: AppColors.of(context).onTint,
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

  Widget _buildStep1BottomBar(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TOTAL PRICE',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(
                      '$totalSeats Seat${totalSeats == 1 ? '' : 's'} Selected',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₱${totalPrice.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.of(context).accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: onProceedToSeats,
              child: const Text('Select seats'),
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
            backgroundColor: AppPalette.danger,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet(BuildContext context, PassengerDetail passenger) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppPalette.radiusXl)),
      ),
      backgroundColor: AppColors.of(context).surface,
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
                  color: AppColors.of(context).hairline,
                  borderRadius:
                      BorderRadius.circular(AppPalette.radiusPill),
                ),
              ),
              Text(
                'Upload Discount ID Photo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Select the source for Passenger ${passenger.index}\'s ID photo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.of(context).tint,
                  child: Icon(Icons.photo_camera_rounded,
                      color: AppColors.of(context).accent),
                ),
                title: Text(
                  'Take Photo (Camera)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  'Capture a clear picture of your physical ID card',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(context, passenger, ImageSource.camera);
                },
              ),
              const Divider(indent: 64, endIndent: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.of(context).tint,
                  child: Icon(Icons.photo_library_rounded,
                      color: AppColors.of(context).accent),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  'Select a photo or scan already saved on your phone',
                  style: Theme.of(context).textTheme.bodySmall,
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
