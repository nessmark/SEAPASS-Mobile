import 'package:flutter/material.dart';

import '../../../models/passenger_booking_models.dart';
import '../../../models/route_fare.dart';
import '../../../models/schedule.dart';
import '../../../widgets/app_palette.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.deepOrange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: AppPalette.darkText),
                    children: [
                      const TextSpan(text: 'Please secure your booking within '),
                      TextSpan(
                        text: formattedHoldTime,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Select Payment Method
        Text(
          'Select a Payment Method',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppPalette.darkText,
              ),
        ),
        const SizedBox(height: 10),

        ...paymentMethods.map((pm) => _buildPaymentTile(pm)),

        const SizedBox(height: 20),

        // Trip & Passenger Summary Card
        _buildBookingInfoSummaryCard(),

        const SizedBox(height: 20),

        // Itemized Price Details Card
        _buildItemizedPriceCard(),

        const SizedBox(height: 24),

        // Confirm & Pay Action
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBackToSeats,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('← Back to Seats'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onConfirmAndPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.mintGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'CONFIRM & PAY (₱${totalPrice.toStringAsFixed(2)})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
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

  Widget _buildPaymentTile(PaymentMethodOption option) {
    final bool isSelected = selectedPaymentId == option.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppPalette.mintGreen : Colors.grey.shade300,
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: () => onPaymentMethodSelected(option.id),
        leading: Icon(
          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: isSelected ? AppPalette.mintGreen : Colors.grey,
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (option.badge.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppPalette.mintGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    option.badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.mintGreen,
                    ),
                  ),
                ),
            ],
          ),
        ),
        subtitle: Text(
          option.subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Icon(option.icon, color: AppPalette.mintGreen, size: 28),
      ),
    );
  }

  Widget _buildBookingInfoSummaryCard() {
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
          const Text(
            'Booking Info',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${schedule.from} → ${schedule.to}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.mintGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  schedule.boatName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppPalette.mintGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Date: ${schedule.date} • Departure: ${schedule.time}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          // Assigned Passengers & Seats
          const Text(
            'Assigned Passengers & Seats:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          ...passengers.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'P${p.index}: ${p.fullName} (${p.categoryLabel})',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Seat ${p.assignedSeat ?? '--'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppPalette.mintGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemizedPriceCard() {
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
          const Text(
            'Price Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),

          if (regularCount > 0)
            _buildPriceDetailRow(
              '$regularCount × Adult Regular (₱${fare.regular.toStringAsFixed(2)})',
              '₱${(regularCount * fare.regular).toStringAsFixed(2)}',
            ),

          if (studentCount > 0)
            _buildPriceDetailRow(
              '$studentCount × Student (₱${fare.student.toStringAsFixed(2)})',
              '₱${(studentCount * fare.student).toStringAsFixed(2)}',
            ),

          if (seniorCount > 0)
            _buildPriceDetailRow(
              '$seniorCount × Senior/PWD (₱${fare.senior.toStringAsFixed(2)})',
              '₱${(seniorCount * fare.senior).toStringAsFixed(2)}',
            ),

          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount Payable',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                '₱${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.mintGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
