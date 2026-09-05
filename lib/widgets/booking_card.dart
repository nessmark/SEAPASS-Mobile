import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../widgets/app_palette.dart';

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.onViewTicket,
  });

  final Booking booking;
  final VoidCallback onViewTicket;

  @override
  Widget build(BuildContext context) {
    final bool isConfirmed = booking.isConfirmed;
    final seatsLabel = booking.seatNumbers.isNotEmpty
        ? (booking.seatNumbers.length == 1
            ? 'Seat ${booking.seatNumbers.first}'
            : 'Seats: ${booking.seatNumbers.join(", ")}')
        : '${booking.seatCount} Seat${booking.seatCount > 1 ? "s" : ""}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isConfirmed
              ? AppPalette.mintGreen.withValues(alpha: 0.4)
              : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onViewTicket,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      booking.route,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConfirmed
                          ? AppPalette.mintGreen.withValues(alpha: 0.15)
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isConfirmed ? 'Confirmed' : 'To be confirmed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isConfirmed
                            ? const Color(0xFF0D5C3A)
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Ref: ${booking.referenceNumber}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Date: ${booking.date}${booking.time.isNotEmpty ? " · ${booking.time}" : ""}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.directions_boat, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Vessel: ${booking.boatName} ($seatsLabel)',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Passenger: ${booking.passengerName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '₱${booking.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.darkText,
                    ),
                  ),
                ],
              ),
              if (isConfirmed) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onViewTicket,
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text('VIEW TICKET & QR CODE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.mintGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
