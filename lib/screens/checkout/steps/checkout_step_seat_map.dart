import 'package:flutter/material.dart';

import '../../../models/passenger_booking_models.dart';
import '../../../models/schedule.dart';
import '../../../widgets/app_palette.dart';
import '../../../widgets/app_card.dart';

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    schedule.boatName.isNotEmpty
                        ? schedule.boatName
                        : 'Vessel Cabin Seat Map',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.of(context).text,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppPalette.info.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Economy Class',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppPalette.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${schedule.from} → ${schedule.to} • ${schedule.time}',
                      style: TextStyle(fontSize: 13, color: AppColors.of(context).text2),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: isRefreshing ? null : onManualRefresh,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.teal500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isRefreshing)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppPalette.teal500,
                              ),
                            )
                          else
                            const Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: AppPalette.teal500,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            isRefreshing ? 'Refreshing...' : 'Refresh Seats',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.teal500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Active Passenger Selection Chips
        Text(
          'Select Passenger to Assign Seat:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.of(context).text2,
          ),
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasSeat
                            ? AppPalette.teal500
                            : AppColors.of(context).text3,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasSeat ? p.assignedSeat! : '--',
                        style: const TextStyle(
                          color: AppPalette.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                selected: isCurrent,
                selectedColor: AppPalette.teal500.withValues(alpha: 0.2),
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
                bottom: Radius.circular(20),
              ),
              
              boxShadow: [
                BoxShadow(
                  color: AppPalette.ink.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Front / Bow Indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surface2,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.navigation_rounded, size: 14, color: AppPalette.teal500),
                      SizedBox(width: 4),
                      Text(
                        'FRONT / BOW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.of(context).text3,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Exit Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('« EXIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.of(context).text3)),
                    Text('EXIT »', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.of(context).text3)),
                  ],
                ),
                const Divider(height: 20),

                // Seat Rows
                ...List.generate(totalRows, (rIndex) => _buildSeatRow(context, rIndex + 1)),

                const SizedBox(height: 10),
                Text(
                  'AFT / STERN',
                  style: TextStyle(fontSize: 10, color: AppColors.of(context).text3, letterSpacing: 0.8),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assigned: $assignedCount / $totalSeats Seats',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  if (activePassenger != null)
                    Text(
                      'Editing: P${activePassenger.index}',
                      style: const TextStyle(
                        color: AppPalette.teal500,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onBackToDetails,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: assignedCount == totalSeats ? onProceedToPayment : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.teal500,
                        foregroundColor: AppPalette.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Review & pay',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem(context, 'Available', AppPalette.white, AppPalette.info, const Text('')),
        _buildLegendItem(context, 'Selected', AppPalette.teal500, AppPalette.teal500, const Icon(Icons.check, size: 12, color: AppPalette.white)),
        _buildLegendItem(context, 'Booked', AppColors.of(context).surface2, AppColors.of(context).hairline, Icon(Icons.close, size: 12, color: AppColors.of(context).text3)),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color fill, Color border, Widget child) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(6),
            
          ),
          child: Center(child: child),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.of(context).text3)),
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.of(context).text3,
              ),
            ),
          ),

          // Right bank [C] [D] [E]
          ...rightSide.map((seat) => _buildSeatBox(context, seat)),
        ],
      ),
    );
  }

  Widget _buildSeatBox(BuildContext context, VesselSeat seat) {
    Color bg = AppPalette.white;
    Color border = AppPalette.info.withValues(alpha: .12);
    Widget child = Text(
      seat.column,
      style: TextStyle(
        fontSize: 12,
        color: AppPalette.info,
        fontWeight: FontWeight.w600,
      ),
    );

    if (seat.isBooked) {
      bg = AppColors.of(context).surface2;
      border = AppColors.of(context).hairline;
      child = Icon(Icons.close, size: 14, color: AppColors.of(context).text3);
    } else if (seat.isSelected) {
      bg = AppPalette.teal500;
      border = AppPalette.teal500;
      child = Text(
        'P${seat.assignedPassengerIndex}',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppPalette.white),
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
          borderRadius: BorderRadius.circular(8),
          
        ),
        child: Center(child: child),
      ),
    );
  }
}
