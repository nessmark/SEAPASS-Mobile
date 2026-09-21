import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/booking.dart';
import '../widgets/app_palette.dart';
import '../widgets/app_card.dart';

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
        backgroundColor: isError ? AppPalette.danger : AppPalette.teal500,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: AppPalette.white,
            ),
            const SizedBox(width: 10),
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

  Color _getStatusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'confirmed':
        return AppPalette.teal500;
      case 'pending':
        return AppPalette.warning;
      case 'to_be_confirmed':
      case 'to be confirmed':
        return AppPalette.warning;
      case 'cancelled':
      case 'canceled':
      default:
        return AppPalette.danger;
    }
  }

  String _getStatusText(String status) {
    switch (status.trim().toLowerCase()) {
      case 'confirmed':
        return 'CONFIRMED';
      case 'pending':
        return 'PENDING';
      case 'to_be_confirmed':
      case 'to be confirmed':
        return 'TO BE CONFIRMED (PENDING ID)';
      case 'cancelled':
      case 'canceled':
        return 'CANCELLED / REFUNDED';
      default:
        return status.toUpperCase();
    }
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
    final String statusLabel = _getStatusText(bookingStatus);
    final Color statusColor = _getStatusColor(bookingStatus);

    return Scaffold(
      backgroundColor: AppColors.of(context).canvas,
      appBar: AppBar(
        title: Text(
          tickets.length > 1
              ? 'PASSENGER E-TICKETS (${tickets.length})'
              : 'E-TICKET & BOARDING PASS',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Shared Trip & Vessel Header Banner ─────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.of(context).text,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.ink.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_boat_filled_rounded,
                              size: 18,
                              color: AppPalette.teal500,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              boatName,
                              style: const TextStyle(
                                color: AppPalette.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      route,
                      style: const TextStyle(
                        color: AppPalette.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 14, color: AppPalette.white.withValues(alpha: .70)),
                        const SizedBox(width: 6),
                        Text(
                          '$tripDate · $tripTime',
                          style: TextStyle(
                            color: AppPalette.white.withValues(alpha: .70),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.of(context).surface.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${tickets.length} Ticket${tickets.length > 1 ? "s" : ""} · ₱${totalCalculated.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppPalette.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Holding State Banner for Discount ID Verification ─────────
              if (bookingStatus.trim().toLowerCase() == 'to_be_confirmed' ||
                  bookingStatus.trim().toLowerCase() == 'to be confirmed')
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppPalette.warning.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                    
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.warning.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppPalette.warning.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          color: AppPalette.warning,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Awaiting Admin ID Verification',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppPalette.warningText,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Your payment was received via GCash/PayMongo. Port administrators will inspect your uploaded Student/Senior/PWD ID photo. Boarding pass QR codes will unlock once approved.\n\n🛡 Automatic GCash refund is issued if rejected.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppPalette.warningText,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Stack of Individual Passenger Ticket Cards ─────────────────
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

              const SizedBox(height: 12),

              // ── Action Buttons ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () => _saveAllTicketsToGallery(tickets, ticketId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.teal500,
                    disabledBackgroundColor:
                        AppPalette.teal500.withValues(alpha: 0.6),
                    foregroundColor: AppPalette.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(AppPalette.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              tickets.length > 1
                                  ? 'SAVING TICKET $_savingProgress OF ${tickets.length}...'
                                  : 'SAVING TO GALLERY...',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                letterSpacing: 0,
                                color: AppPalette.white,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.download_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              tickets.length > 1
                                  ? 'DOWNLOAD / SAVE ALL TICKETS (${tickets.length})'
                                  : 'DOWNLOAD / SAVE TO GALLERY',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.of(context).text,
                    
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
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
    final Color statusColor = _getStatusColor(bookingStatus);

    // Unique QR payload per passenger per exact specification
    final Map<String, dynamic> qrPayload = {
      'booking_ref': bookingRef,
      'passenger_id': passenger.id,
      'passenger_name': passenger.name,
      'seat': passenger.seat,
      'vessel': vessel,
    };
    final String qrData = jsonEncode(qrPayload);

    return AppCard(padding: EdgeInsets.zero,
      key: ValueKey('${passenger.id}_${passenger.seat}'),
      margin: const EdgeInsets.only(bottom: 18),
      
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ticket Header Strip ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.only(left: 14, right: 12, top: 11, bottom: 11),
            decoration: BoxDecoration(
              color: AppColors.of(context).text,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                // Passenger ID Badge (e.g. P1)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppPalette.teal500,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    passenger.id,
                    style: const TextStyle(
                      color: AppPalette.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Boarding Pass Title with ellipsis guard
                Expanded(
                  child: Text(
                    totalTickets > 1
                        ? 'TICKET ${index + 1} OF $totalTickets'
                        : 'INDIVIDUAL BOARDING PASS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppPalette.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Status Badge with Flexible and ellipsis guard
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isConfirmed ? 'BOARDING PASS' : 'PENDING CONFIRMATION',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Dedicated QR Code per Passenger (Or Locked Placeholder) ───────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Center(
              child: Column(
                children: [
                  if (isConfirmed) ...[
                    AppCard(
                      padding: const EdgeInsets.all(10),
                      
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 190.0,
                        backgroundColor: AppColors.of(context).surface,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.of(context).text,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.of(context).text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ref: $bookingRef · Seat ${passenger.seat}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: AppColors.of(context).text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.teal500.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 14,
                            color: AppPalette.success,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'SCAN AT PORT FOR BOARDING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppPalette.success,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Holding state / Cancelled state placeholder
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 170),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: (bookingStatus.toLowerCase().contains('cancel'))
                            ? AppPalette.danger.withValues(alpha: .12)
                            : AppPalette.warning.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                        
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            (bookingStatus.toLowerCase().contains('cancel'))
                                ? Icons.cancel_outlined
                                : Icons.hourglass_empty_rounded,
                            size: 44,
                            color: (bookingStatus.toLowerCase().contains('cancel'))
                                ? AppPalette.danger
                                : AppPalette.warning,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            (bookingStatus.toLowerCase().contains('cancel'))
                                ? 'BOOKING CANCELLED'
                                : 'BOARDING QR LOCKED',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 0,
                              color: (bookingStatus.toLowerCase().contains('cancel'))
                                  ? AppPalette.dangerText
                                  : AppPalette.warningText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (bookingStatus.toLowerCase().contains('cancel'))
                                ? 'This ticket was cancelled and refunded.'
                                : 'QR code will unlock once port administrators verify and approve your discounted ID.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: (bookingStatus.toLowerCase().contains('cancel'))
                                  ? AppPalette.dangerText
                                  : AppPalette.warningText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ref: $bookingRef · Seat ${passenger.seat}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        color: AppColors.of(context).text,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Perforated Tear Line with Cutout Notches ───────────────────────
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
                        color: AppColors.of(context).hairline,
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
                      color: AppColors.of(context).canvas,
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
                      color: AppColors.of(context).canvas,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Passenger Details & Receipt Section ───────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReceiptRow('Passenger Name', passenger.name),
                _buildReceiptRow('Booking Ref', bookingRef),

                // Prominent Assigned Seat
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          'Assigned Seat(s):',
                          style: TextStyle(
                            color: AppColors.of(context).text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppPalette.teal500.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.event_seat_rounded,
                                    size: 15, color: AppPalette.success),
                                const SizedBox(width: 5),
                                Text(
                                  passenger.seat,
                                  style: const TextStyle(
                                    color: AppPalette.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildReceiptRow('Fare Category', passenger.categoryDisplay),
                _buildReceiptRow('Trip Schedule', '$date · $time'),
                _buildReceiptRow('Vessel Name', vessel),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Individual Fare',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.of(context).text2,
                      ),
                    ),
                    Text(
                      '₱${passenger.individualFare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.teal500,
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

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.of(context).text2,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.of(context).text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
