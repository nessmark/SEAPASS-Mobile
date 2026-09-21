import 'package:flutter/material.dart';

import '../../../models/passenger_booking_models.dart';
import '../../../models/schedule.dart';
import '../../../widgets/app_palette.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/status_chip.dart';

/// Step 2 of the booking checkout flow:
/// Displays the vessel cabin layout, legend, passenger seat assignments, and interactive seat grid.
class CheckoutStepSeatMap extends StatelessWidget {
  const CheckoutStepSeatMap({
    super.key,
    required this.schedule,
    required this.passengers,
    required this.seats,
    required this.activePassengerIndex,
    required this.totalSeats,
    required this.totalRows,
    required this.isRefreshing,
    required this.onActivePassengerChanged,
    required this.onSeatTapped,
    required this.onBackToDetails,
    required this.onProceedToPayment,
    required this.onManualRefresh,
  });

  final Schedule schedule;
  final List<PassengerDetail> passengers;
  final List<VesselSeat> seats;
  final int activePassengerIndex;
  final int totalSeats;
  final int totalRows;
  final bool isRefreshing;

  final void Function(int index) onActivePassengerChanged;
  final void Function(VesselSeat seat) onSeatTapped;
  final VoidCallback onBackToDetails;
  final VoidCallback onProceedToPayment;
  final VoidCallback onManualRefresh;

  @override
  Widget build(BuildContext context) {
    final activePassenger = passengers.isNotEmpty && activePassengerIndex < passengers.length
        ? passengers[activePassengerIndex]
        : null;

    final int assignedCount = passengers.where((p) => p.assignedSeat != null && p.assignedSeat!.isNotEmpty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vessel Cabin Header Card
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      schedule.boatName.isNotEmpty
                          ? schedule.boatName
                          : 'Vessel Cabin Seat Map',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const StatusChip(label: 'Economy Class'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${schedule.from} → ${schedule.to} • ${schedule.time}',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: isRefreshing ? null : onManualRefresh,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.of(context).tint,
                      foregroundColor: AppColors.of(context).onTint,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: Theme.of(context).textTheme.labelMedium,
                      shape: const StadiumBorder(),
                    ),
                    icon: isRefreshing
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.of(context).onTint,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 14),
                    label: Text(isRefreshing ? 'Refreshing...' : 'Refresh Seats'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Active Passenger Selection Chips
        Text(
          'Select Passenger to Assign Seat',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: passengers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = passengers[i];
              final bool isCurrent = i == activePassengerIndex;
              final bool hasSeat = p.assignedSeat != null && p.assignedSeat!.isNotEmpty;

              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'P${p.index}: ${p.fullName}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight:
                                isCurrent ? FontWeight.w600 : FontWeight.w400,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasSeat
                            ? AppColors.of(context).accent
                            : AppColors.of(context).text3,
                        borderRadius:
                            BorderRadius.circular(AppPalette.radiusPill),
                      ),
                      child: Text(
                        hasSeat ? p.assignedSeat! : '--',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                color: AppPalette.white, letterSpacing: 0),
                      ),
                    ),
                  ],
                ),
                selected: isCurrent,
                selectedColor: AppColors.of(context).tint,
                onSelected: (_) => onActivePassengerChanged(i),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Seat Status Legend (Available, Selected, Unavailable)
        _buildSeatLegend(context),
        const SizedBox(height: 14),

        // Vessel Cabin Visual Outline & Grid
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(60),
                bottom: Radius.circular(AppPalette.radiusLg),
              ),
              boxShadow: AppPalette.shadows(Theme.of(context).brightness),
            ),
            child: Column(
              children: [
                // Front / Bow Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surface2,
                    borderRadius:
                        BorderRadius.circular(AppPalette.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.navigation_rounded,
                          size: 14, color: AppColors.of(context).accent),
                      const SizedBox(width: 4),
                      Text(
                        'FRONT / BOW',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Exit Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('« EXIT',
                        style: Theme.of(context).textTheme.labelSmall),
                    Text('EXIT »',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
                const Divider(height: 20),

                // Seat Rows — a wide vessel layout must shrink to fit a narrow
                // phone rather than overflow, so the whole block scales down.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      totalRows,
                      (rIndex) => _buildSeatRow(context, rIndex + 1),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                Text(
                  'AFT / STERN',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Bottom Controls
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Assigned: $assignedCount / $totalSeats Seats',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (activePassenger != null)
                    Text(
                      'Editing: P${activePassenger.index}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.of(context).accent),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: onBackToDetails,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.of(context).tint,
                        foregroundColor: AppColors.of(context).onTint,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Details',
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: assignedCount == totalSeats ? onProceedToPayment : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Review & pay',
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSeatLegend(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: AppPalette.space16,
      runSpacing: AppPalette.space8,
      children: [
        _buildLegendItem(context, 'Available', colors.tint, const Text('')),
        _buildLegendItem(context, 'Selected', colors.accent,
            const Icon(Icons.check, size: 12, color: AppPalette.white)),
        _buildLegendItem(context, 'Booked', colors.surface2,
            Icon(Icons.close, size: 12, color: colors.text3)),
      ],
    );
  }

  Widget _buildLegendItem(
      BuildContext context, String label, Color fill, Widget child) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(AppPalette.radiusSm),
          ),
          child: Center(child: child),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _buildSeatRow(BuildContext context, int rowNumber) {
    final rowSeats = seats.where((s) => s.row == rowNumber).toList();
    final leftSide = rowSeats.where((s) => s.column == 'A' || s.column == 'B').toList();
    final rightSide = rowSeats.where((s) => s.column == 'C' || s.column == 'D' || s.column == 'E').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left bank [A] [B]
          ...leftSide.map((seat) => _buildSeatBox(context, seat)),

          // Aisle with row number
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$rowNumber',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),

          // Right bank [C] [D] [E]
          ...rightSide.map((seat) => _buildSeatBox(context, seat)),
        ],
      ),
    );
  }

  Widget _buildSeatBox(BuildContext context, VesselSeat seat) {
    final colors = AppColors.of(context);
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    Color bg = colors.tint;
    Widget child = Text(
      seat.column,
      style: labelStyle?.copyWith(fontSize: 12, color: colors.onTint),
    );

    if (seat.isBooked) {
      bg = colors.surface2;
      child = Icon(Icons.close, size: 14, color: colors.text3);
    } else if (seat.isSelected) {
      bg = colors.accent;
      child = Text(
        'P${seat.assignedPassengerIndex}',
        style: labelStyle?.copyWith(fontSize: 10, color: AppPalette.white),
      );
    }

    return GestureDetector(
      onTap: () => onSeatTapped(seat),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppPalette.radiusSm),
        ),
        child: Center(child: child),
      ),
    );
  }
}
