import 'package:flutter/material.dart';

import '../../../models/passenger_booking_models.dart';
import '../../../models/route_fare.dart';
import '../../../models/schedule.dart';
import '../../../widgets/app_palette.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/status_chip.dart';

/// Step 3 of the booking checkout flow:
/// Displays the hold countdown banner, payment gateway selection, summary card, itemized fares, and confirmation action.
class CheckoutStepPayment extends StatelessWidget {
  const CheckoutStepPayment({
    super.key,
    required this.schedule,
    required this.fare,
    required this.regularCount,
    required this.studentCount,
    required this.seniorCount,
    required this.totalPrice,
    required this.passengers,
    required this.formattedHoldTime,
    required this.paymentMethods,
    required this.selectedPaymentId,
    required this.isSubmitting,
    required this.onPaymentMethodSelected,
    required this.onBackToSeats,
    required this.onConfirmAndPay,
  });

  final Schedule schedule;
  final RouteFare fare;
  final int regularCount;
  final int studentCount;
  final int seniorCount;
  final double totalPrice;
  final List<PassengerDetail> passengers;
  final String formattedHoldTime;
  final List<PaymentMethodOption> paymentMethods;
  final String selectedPaymentId;
  final bool isSubmitting;

  final void Function(String id) onPaymentMethodSelected;
  final VoidCallback onBackToSeats;
  final VoidCallback onConfirmAndPay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hold Countdown Timer Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: AppPalette.warning.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppPalette.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppPalette.warning, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Please secure your booking within '),
                      TextSpan(
                        text: formattedHoldTime,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.warning,
                        ),
                      ),
                    ],
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.of(context).text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Select Payment Method
        const SectionHeader('Select a Payment Method'),

        ...paymentMethods.map((pm) => _buildPaymentTile(context, pm)),

        const SizedBox(height: 20),

        // Trip & Passenger Summary Card
        _buildBookingInfoSummaryCard(context),

        const SizedBox(height: 20),

        // Itemized Price Details Card
        _buildItemizedPriceCard(context),

        const SizedBox(height: 24),

        // Confirm & Pay Action
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: onBackToSeats,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.of(context).tint,
                  foregroundColor: AppColors.of(context).onTint,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  textStyle: Theme.of(context).textTheme.labelMedium,
                ),
                child: const Text('Back to seats',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: isSubmitting ? null : onConfirmAndPay,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor:
                        AppPalette.teal500.withValues(alpha: .6),
                    disabledForegroundColor: AppPalette.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppPalette.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Pay (₱${totalPrice.toStringAsFixed(2)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPaymentTile(BuildContext context, PaymentMethodOption option) {
    final bool isSelected = selectedPaymentId == option.id;

    return AppCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: () => onPaymentMethodSelected(option.id),
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected
              ? AppColors.of(context).accent
              : AppColors.of(context).text3,
        ),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                option.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (option.badge.isNotEmpty) StatusChip(label: option.badge),
            ],
          ),
        ),
        subtitle: Text(
          option.subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Icon(option.icon, color: AppColors.of(context).accent, size: 28),
      ),
    );
  }

  Widget _buildBookingInfoSummaryCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking Info', style: Theme.of(context).textTheme.titleLarge),
          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${schedule.from} → ${schedule.to}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 12),
              if (schedule.boatName.isNotEmpty)
                Flexible(child: StatusChip(label: schedule.boatName)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Date: ${schedule.date} • Departure: ${schedule.time}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),

          // Assigned Passengers & Seats
          Text(
            'ASSIGNED PASSENGERS & SEATS',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          ...passengers.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'P${p.index}: ${p.fullName} (${p.categoryLabel})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Seat ${p.assignedSeat ?? '--'}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.of(context).accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemizedPriceCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Price Details', style: Theme.of(context).textTheme.titleLarge),
          const Divider(height: 20),

          if (regularCount > 0)
            _buildPriceDetailRow(context, 
              '$regularCount × Adult Regular (₱${fare.regular.toStringAsFixed(2)})',
              '₱${(regularCount * fare.regular).toStringAsFixed(2)}',
            ),

          if (studentCount > 0)
            _buildPriceDetailRow(context, 
              '$studentCount × Student (₱${fare.student.toStringAsFixed(2)})',
              '₱${(studentCount * fare.student).toStringAsFixed(2)}',
            ),

          if (seniorCount > 0)
            _buildPriceDetailRow(context, 
              '$seniorCount × Senior/PWD (₱${fare.senior.toStringAsFixed(2)})',
              '₱${(seniorCount * fare.senior).toStringAsFixed(2)}',
            ),

          const Divider(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Total Amount Payable',
                  style: Theme.of(context).textTheme.titleSmall,
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
        ],
      ),
    );
  }

  Widget _buildPriceDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 12),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
