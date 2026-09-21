import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/booking.dart';
import '../widgets/app_card.dart';
import '../widgets/app_palette.dart';
import '../widgets/status_chip.dart';

class ViewTicketScreen extends StatefulWidget {
  const ViewTicketScreen({super.key, this.booking});

  static const String routeName = '/ticket';
  final Booking? booking;

  @override
  State<ViewTicketScreen> createState() => _ViewTicketScreenState();
}

class _ViewTicketScreenState extends State<ViewTicketScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _ticketKeys = {};
  bool _isSaving = false;
  int _savingProgress = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _getKeyForIndex(int index) {
    return _ticketKeys.putIfAbsent(index, () => GlobalKey());
  }

  /// Captures the RepaintBoundary widget into high-res PNG byte data.
  Future<Uint8List?> _captureTicketPng(GlobalKey key) async {
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        final BuildContext? context = key.currentContext;
        if (context == null || !context.mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }

        final RenderObject? renderObject = context.findRenderObject();
        if (renderObject is! RenderRepaintBoundary) {
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }

        // Wait for frame to finish rendering so the repaint boundary is fully painted
        if (WidgetsBinding.instance.hasScheduledFrame) {
          await WidgetsBinding.instance.endOfFrame;
        }

        // pixelRatio: 3.0 renders a sharp 3x scale image for crisp QR codes and typography
        final ui.Image image = await renderObject.toImage(pixelRatio: 3.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          return byteData.buffer.asUint8List();
        }
      } catch (e) {
        debugPrint('[SeaPass] RepaintBoundary capture attempt $attempt: $e');
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }
    return null;
  }

  /// Loops through all ticket RepaintBoundaries, renders PNGs, and writes to gallery.
  Future<void> _saveAllTicketsToGallery(
    List<PassengerTicketInfo> tickets,
    String bookingRef,
  ) async {
    if (_isSaving || tickets.isEmpty) return;

    setState(() {
      _isSaving = true;
      _savingProgress = 0;
    });

    try {
      // 1. Verify / Request Gallery Storage Access
      final bool hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final bool granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          if (mounted) {
            _showFeedbackSnackBar(
              message:
                  'Storage permission denied. Please grant permission in App Settings to save tickets.',
              isError: true,
            );
          }
          return;
        }
      }

      int savedCount = 0;

      for (int i = 0; i < tickets.length; i++) {
        final passenger = tickets[i];
        final key = _getKeyForIndex(i);

        if (mounted) {
          setState(() {
            _savingProgress = i + 1;
          });
        }

        // Ensure ticket card is in viewport and repainted
        if (key.currentContext != null) {
          await Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 160),
            alignment: 0.05,
          );
          await Future.delayed(const Duration(milliseconds: 180));
        } else {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        final Uint8List? pngBytes = await _captureTicketPng(key);
        if (pngBytes == null) {
          debugPrint(
              '[SeaPass] Failed to capture ticket image for seat ${passenger.seat}');
          continue;
        }

        // Clean filename format: SeaPass_Ticket_SP-20260905-0015_Seat4C
        final sanitizedRef =
            bookingRef.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final sanitizedSeat =
            passenger.seat.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final fileName =
            'SeaPass_Ticket_${sanitizedRef}_Seat$sanitizedSeat';

        await Gal.putImageBytes(
          pngBytes,
          name: fileName,
        );

        savedCount++;
      }

      // Smoothly scroll back to the top of the ticket screen
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }

      if (mounted) {
        if (savedCount > 0) {
          _showFeedbackSnackBar(
            message: savedCount == 1
                ? '1 Ticket saved to Gallery successfully!'
                : '$savedCount Tickets saved to Gallery successfully!',
            isError: false,
          );
        } else {
          _showFeedbackSnackBar(
            message: 'Could not generate ticket images. Please try again.',
            isError: true,
          );
        }
      }
    } on GalException catch (e) {
      debugPrint('[SeaPass] GalException: ${e.type}');
      if (mounted) {
        _showFeedbackSnackBar(
          message: 'Gallery save error: ${e.type.message}',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('[SeaPass] Ticket save exception: $e');
      if (mounted) {
        _showFeedbackSnackBar(
          message: 'Failed to save tickets: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingProgress = 0;
        });
      }
    }
  }

  void _showFeedbackSnackBar({required String message, bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppPalette.danger : AppPalette.teal600,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: AppPalette.white,
            ),
            const SizedBox(width: AppPalette.space12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppPalette.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ─── Status helpers ─────────────────────────────────────────────────────────

  StatusTone _statusTone(String status) {
    switch (status.trim().toLowerCase()) {
      case 'confirmed':
        return StatusTone.success;
      case 'pending':
      case 'to_be_confirmed':
      case 'to be confirmed':
        return StatusTone.warning;
      case 'cancelled':
      case 'canceled':
      default:
        return StatusTone.danger;
    }
  }

  String _getStatusText(String status) {
    switch (status.trim().toLowerCase()) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'to_be_confirmed':
      case 'to be confirmed':
        return 'Awaiting ID check';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Splits "Surigao → San Jose" into its two ports for the route line.
  /// Falls back to the raw string when the shape is unexpected.
  List<String> _splitRoute(String route) {
    for (final separator in ['→', '->', ' to ', ' - ', '–']) {
      if (route.contains(separator)) {
        final parts = route.split(separator);
        if (parts.length == 2 &&
            parts[0].trim().isNotEmpty &&
            parts[1].trim().isNotEmpty) {
          return [parts[0].trim(), parts[1].trim()];
        }
      }
    }
    return [route.trim()];
  }

  @override
  Widget build(BuildContext context) {
    final passedBooking = widget.booking ??
        (ModalRoute.of(context)?.settings.arguments is Booking
            ? ModalRoute.of(context)!.settings.arguments as Booking
            : null);

    // If no booking was passed, go back — never show hardcoded/demo data
    if (passedBooking == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final String ticketId = passedBooking.referenceNumber.isNotEmpty
        ? passedBooking.referenceNumber
        : 'SP-${passedBooking.id}';
    final String route = passedBooking.route;
    final String boatName = passedBooking.boatName.isNotEmpty
        ? passedBooking.boatName
        : 'Vessel';
    final String tripDate = passedBooking.date;
    final String tripTime = passedBooking.time;

    // Extract individual passenger tickets (supports 1, 2, or more passengers)
    final List<PassengerTicketInfo> tickets = passedBooking.passengerTickets;

    final double totalCalculated = passedBooking.calculatedTotalFare > 0
        ? passedBooking.calculatedTotalFare
        : tickets.fold<double>(0.0, (sum, t) => sum + t.individualFare);

    final String bookingStatus = passedBooking.status;
    final bool isHolding =
        bookingStatus.trim().toLowerCase() == 'to_be_confirmed' ||
            bookingStatus.trim().toLowerCase() == 'to be confirmed';

    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      appBar: AppBar(
        title: Text(tickets.length > 1 ? 'Boarding passes' : 'Boarding pass'),
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(AppPalette.space20,
              AppPalette.space16, AppPalette.space20, AppPalette.space32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Shared trip summary ────────────────────────────────────────
              _buildTripSummary(
                route: route,
                vessel: boatName,
                date: tripDate,
                time: tripTime,
                status: bookingStatus,
                ticketCount: tickets.length,
                total: totalCalculated,
              ),

              const SizedBox(height: AppPalette.space16),

              // ── Holding state banner for discount ID verification ─────────
              if (isHolding) ...[
                _buildHoldingBanner(),
                const SizedBox(height: AppPalette.space16),
              ],

              // ── Stack of individual passenger ticket cards ────────────────
              ...tickets.asMap().entries.map((entry) {
                final int index = entry.key;
                final PassengerTicketInfo passenger = entry.value;
                return RepaintBoundary(
                  key: _getKeyForIndex(index),
                  child: Container(
                    color: AppColors.of(context).canvas,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _buildPassengerTicketCard(
                      context: context,
                      index: index,
                      totalTickets: tickets.length,
                      passenger: passenger,
                      bookingRef: ticketId,
                      bookingStatus: bookingStatus,
                      vessel: boatName,
                      route: route,
                      date: tripDate,
                      time: tripTime,
                    ),
                  ),
                );
              }),

              const SizedBox(height: AppPalette.space8),

              // ── Actions ────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _saveAllTicketsToGallery(tickets, ticketId),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(AppPalette.white),
                          ),
                        )
                      : const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    _isSaving
                        ? (tickets.length > 1
                            ? 'Saving ticket $_savingProgress of ${tickets.length}…'
                            : 'Saving to gallery…')
                        : (tickets.length > 1
                            ? 'Save all ${tickets.length} tickets'
                            : 'Save to gallery'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: AppPalette.space12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Trip summary ───────────────────────────────────────────────────────────

  Widget _buildTripSummary({
    required String route,
    required String vessel,
    required String date,
    required String time,
    required String status,
    required int ticketCount,
    required double total,
  }) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final ports = _splitRoute(route);

    return AppCard(
      padding: const EdgeInsets.all(AppPalette.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_boat_filled_rounded,
                  size: 18, color: colors.accent),
              const SizedBox(width: AppPalette.space8),
              Expanded(
                child: Text(
                  vessel,
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppPalette.space8),
              StatusChip(
                label: _getStatusText(status),
                tone: _statusTone(status),
              ),
            ],
          ),
          const SizedBox(height: AppPalette.space16),

          // Route line
          if (ports.length == 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(ports.first,
                      style: text.headlineMedium, maxLines: 2),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppPalette.space8),
                  child: Icon(Icons.arrow_right_alt_rounded,
                      size: 24, color: colors.text3),
                ),
                Expanded(
                  child: Text(ports.last,
                      style: text.headlineMedium,
                      maxLines: 2,
                      textAlign: TextAlign.end),
                ),
              ],
            )
          else
            Text(route, style: text.headlineMedium),

          const SizedBox(height: AppPalette.space16),

          // Departure time, big and tabular
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DEPARTS', style: text.labelSmall),
                    const SizedBox(height: AppPalette.space4),
                    Text(
                      time.isNotEmpty ? time : '—',
                      style: text.displayMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(date, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppPalette.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$ticketCount ticket${ticketCount == 1 ? "" : "s"}',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppPalette.space4),
                  Text(
                    '₱${total.toStringAsFixed(2)}',
                    style: text.titleLarge?.copyWith(color: colors.accent),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHoldingBanner() {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppPalette.space20),
      color: AppPalette.warning.withValues(alpha: .12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded,
              color: AppPalette.warning, size: 24),
          const SizedBox(width: AppPalette.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Awaiting admin ID verification',
                  style: text.titleSmall?.copyWith(
                      color: AppColors.of(context).dark
                          ? AppPalette.warning
                          : AppPalette.warningText),
                ),
                const SizedBox(height: AppPalette.space4),
                Text(
                  'Your payment was received via GCash/PayMongo. Port administrators will inspect your uploaded Student/Senior/PWD ID photo. Boarding pass QR codes unlock once approved.',
                  style: text.bodySmall?.copyWith(
                      color: AppColors.of(context).dark
                          ? AppPalette.warning
                          : AppPalette.warningText),
                ),
                const SizedBox(height: AppPalette.space8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 15, color: AppPalette.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'An automatic GCash refund is issued if it is rejected.',
                        style: text.bodySmall?.copyWith(
                            color: AppColors.of(context).dark
                                ? AppPalette.warning
                                : AppPalette.warningText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Individual Passenger Ticket Component ────────────────────────────────

  Widget _buildPassengerTicketCard({
    required BuildContext context,
    required int index,
    required int totalTickets,
    required PassengerTicketInfo passenger,
    required String bookingRef,
    required String bookingStatus,
    required String vessel,
    required String route,
    required String date,
    required String time,
  }) {
    final bool isConfirmed = bookingStatus.trim().toLowerCase() == 'confirmed';
    final bool isCancelled = bookingStatus.toLowerCase().contains('cancel');
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    // Unique QR payload per passenger per exact specification
    final Map<String, dynamic> qrPayload = {
      'booking_ref': bookingRef,
      'passenger_id': passenger.id,
      'passenger_name': passenger.name,
      'seat': passenger.seat,
      'vessel': vessel,
    };
    final String qrData = jsonEncode(qrPayload);

    return AppCard(
      key: ValueKey('${passenger.id}_${passenger.seat}'),
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: AppPalette.space20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ticket header strip ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppPalette.space20, vertical: AppPalette.space12),
            color: colors.tint,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.teal500,
                    borderRadius: BorderRadius.circular(AppPalette.radiusSm),
                  ),
                  child: Text(
                    passenger.id,
                    style: text.labelMedium?.copyWith(color: AppPalette.white),
                  ),
                ),
                const SizedBox(width: AppPalette.space8),
                Expanded(
                  child: Text(
                    totalTickets > 1
                        ? 'Ticket ${index + 1} of $totalTickets'
                        : 'Boarding pass',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(color: colors.onTint),
                  ),
                ),
                const SizedBox(width: AppPalette.space8),
                Flexible(
                  child: StatusChip(
                    label: isConfirmed ? 'Ready to board' : _getStatusText(bookingStatus),
                    tone: _statusTone(bookingStatus),
                  ),
                ),
              ],
            ),
          ),

          // ── Dedicated QR code per passenger (or locked placeholder) ───────
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppPalette.space24, horizontal: AppPalette.space20),
            child: Center(
              child: Column(
                children: [
                  if (isConfirmed) ...[
                    // The QR stays literal white-on-black so port scanners read
                    // it in either theme.
                    Container(
                      padding: const EdgeInsets.all(AppPalette.space12),
                      decoration: BoxDecoration(
                        color: AppPalette.white,
                        borderRadius:
                            BorderRadius.circular(AppPalette.radiusMd),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 190.0,
                        backgroundColor: AppPalette.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppPalette.ink,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppPalette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppPalette.space16),
                    Text(
                      '$bookingRef · Seat ${passenger.seat}',
                      textAlign: TextAlign.center,
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: AppPalette.space8),
                    const StatusChip(
                      label: 'Scan at port to board',
                      tone: StatusTone.success,
                      icon: Icons.qr_code_scanner_rounded,
                    ),
                  ] else ...[
                    // Holding state / cancelled state placeholder
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 170),
                      padding: const EdgeInsets.all(AppPalette.space20),
                      decoration: BoxDecoration(
                        color: (isCancelled
                                ? AppPalette.danger
                                : AppPalette.warning)
                            .withValues(alpha: .12),
                        borderRadius:
                            BorderRadius.circular(AppPalette.radiusMd),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCancelled
                                ? Icons.cancel_outlined
                                : Icons.hourglass_empty_rounded,
                            size: 44,
                            color: isCancelled
                                ? AppPalette.danger
                                : AppPalette.warning,
                          ),
                          const SizedBox(height: AppPalette.space12),
                          Text(
                            isCancelled
                                ? 'Booking cancelled'
                                : 'Boarding QR locked',
                            textAlign: TextAlign.center,
                            style: text.titleSmall?.copyWith(
                              color: isCancelled
                                  ? (colors.dark
                                      ? AppPalette.danger
                                      : AppPalette.dangerText)
                                  : (colors.dark
                                      ? AppPalette.warning
                                      : AppPalette.warningText),
                            ),
                          ),
                          const SizedBox(height: AppPalette.space4),
                          Text(
                            isCancelled
                                ? 'This ticket was cancelled and refunded.'
                                : 'The QR code unlocks once port administrators verify and approve your discounted ID.',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(
                              color: isCancelled
                                  ? (colors.dark
                                      ? AppPalette.danger
                                      : AppPalette.dangerText)
                                  : (colors.dark
                                      ? AppPalette.warning
                                      : AppPalette.warningText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppPalette.space16),
                    Text(
                      '$bookingRef · Seat ${passenger.seat}',
                      textAlign: TextAlign.center,
                      style: text.titleSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Perforated tear line with cutout notches ───────────────────────
          SizedBox(
            height: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  children: List.generate(
                    28,
                    (_) => Expanded(
                      child: Container(
                        height: 1.5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: colors.hairline,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.canvas,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: -10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.canvas,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Passenger details & receipt section ───────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppPalette.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReceiptRow('Passenger', passenger.name),
                _buildReceiptRow('Booking ref', bookingRef),
                _buildReceiptRow(
                  'Assigned seat',
                  passenger.seat,
                  valueChip: true,
                ),
                _buildReceiptRow('Fare category', passenger.categoryDisplay),
                _buildReceiptRow('Trip schedule', '$date · $time'),
                _buildReceiptRow('Vessel', vessel),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text('Individual fare', style: text.bodySmall),
                    ),
                    const SizedBox(width: AppPalette.space12),
                    Text(
                      '₱${passenger.individualFare.toStringAsFixed(2)}',
                      style: text.headlineMedium?.copyWith(color: colors.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool valueChip = false}) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppPalette.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: text.bodySmall),
          ),
          const SizedBox(width: AppPalette.space12),
          Expanded(
            flex: 6,
            child: valueChip
                ? Align(
                    alignment: Alignment.centerRight,
                    child: StatusChip(
                      label: value,
                      tone: StatusTone.success,
                      icon: Icons.event_seat_rounded,
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.end,
                    style: text.titleSmall?.copyWith(color: colors.text),
                  ),
          ),
        ],
      ),
    );
  }
}
