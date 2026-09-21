import 'package:flutter/material.dart';

import '../models/booking.dart';
import 'app_card.dart';
import 'app_palette.dart';
import 'status_chip.dart';

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

    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppPalette.space16),
      padding: const EdgeInsets.all(AppPalette.space20),
      onTap: onViewTicket,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  booking.route,
                  style: text.titleLarge,
                ),
              ),
              const SizedBox(width: AppPalette.space12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: StatusChip(
                  label: isConfirmed ? 'Confirmed' : 'To be confirmed',
                  tone: isConfirmed ? StatusTone.success : StatusTone.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space16),
          _MetaRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Ref: ${booking.referenceNumber}',
            strong: true,
          ),
          const SizedBox(height: AppPalette.space8),
          _MetaRow(
            icon: Icons.calendar_today_outlined,
            label:
                '${booking.date}${booking.time.isNotEmpty ? " · ${booking.time}" : ""}',
          ),
          const SizedBox(height: AppPalette.space8),
          _MetaRow(
            icon: Icons.directions_boat_outlined,
            label: '${booking.boatName} · $seatsLabel',
          ),
          const SizedBox(height: AppPalette.space16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  booking.passengerName,
                  style: text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppPalette.space12),
              Text(
                '₱${booking.totalPrice.toStringAsFixed(2)}',
                style: text.titleLarge?.copyWith(color: colors.accent),
              ),
            ],
          ),
          if (isConfirmed) ...[
            const SizedBox(height: AppPalette.space16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onViewTicket,
                icon: const Icon(Icons.qr_code_rounded, size: 18),
                label: const Text('View ticket & QR code'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, this.strong = false});
  final IconData icon;
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: colors.text3),
        ),
        const SizedBox(width: AppPalette.space8),
        Expanded(
          child: Text(
            label,
            style: strong
                ? text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                : text.bodyMedium?.copyWith(color: colors.text2),
          ),
        ),
      ],
    );
  }
}
