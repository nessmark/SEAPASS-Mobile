import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api_service.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../services/token_storage_service.dart';
import '../widgets/app_palette.dart';
import 'login_screen.dart';

class ScannerHomeScreen extends StatefulWidget {
  const ScannerHomeScreen({super.key});

  static const String routeName = '/scanner-home';

  @override
  State<ScannerHomeScreen> createState() => _ScannerHomeScreenState();
}

class _ScannerHomeScreenState extends State<ScannerHomeScreen> with WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final PassengerDataService _dataService = const PassengerDataService();
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scannerController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _scannerController.start();
    }
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawCode = barcodes.first.rawValue;
    if (rawCode == null || rawCode.trim().isEmpty) return;

    setState(() => _isProcessing = true);

    // 1. Inspect and parse QR payload
    String referenceNumber = rawCode.trim();
    Map<String, dynamic>? parsedJson;

    try {
      final decoded = jsonDecode(rawCode.trim());
      if (decoded is Map<String, dynamic>) {
        parsedJson = decoded;
        // Extract reference number from JSON payload key variations
        referenceNumber = (parsedJson['booking_ref'] ??
                parsedJson['reference_number'] ??
                parsedJson['ref'] ??
                rawCode.trim())
            .toString()
            .trim();
      }
    } catch (_) {
      // Fallback: rawCode is already a plain reference string (e.g. "SP-20260909-0001")
    }

    // 2. Pass ONLY clean reference number to verification method
    await _verifyTicket(
      referenceNumber: referenceNumber,
      scannedJson: parsedJson,
    );
  }

  Future<void> _verifyTicket({
    required String referenceNumber,
    Map<String, dynamic>? scannedJson,
  }) async {
    try {
      final result = await _dataService.verifyTicket(referenceNumber);
      if (!mounted) return;

      final bool isSuccess = result['success'] == true;

      if (isSuccess) {
        // Haptic feedback & Success chime
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
        _showSuccessModal(
          result['data'] is Map<String, dynamic> ? result['data'] : {},
          scannedJson: scannedJson,
        );
      } else {
        final status = result['status']?.toString() ?? 'ERROR';
        if (status == 'TOO_EARLY') {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.vibrate();
        }
        _showErrorModal(
          status: status,
          message: result['message']?.toString() ?? 'Ticket verification failed.',
          referenceNumber: referenceNumber,
          scannedPassengerName: scannedJson?['passenger_name']?.toString(),
          scannedJson: scannedJson,
          data: result['data'] is Map<String, dynamic> ? result['data'] : null,
        );
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      _showErrorModal(
        status: 'NETWORK_ERROR',
        message: 'Could not connect to SeaPass verification server.\n$e',
        referenceNumber: referenceNumber,
        scannedPassengerName: scannedJson?['passenger_name']?.toString(),
        scannedJson: scannedJson,
      );
    }
  }

  void _showSuccessModal(Map<String, dynamic> data, {Map<String, dynamic>? scannedJson}) {
    final String passengerName = data['passenger_name']?.toString() ??
        scannedJson?['passenger_name']?.toString() ??
        'Passenger';
    final String refNumber = data['reference_number']?.toString() ??
        data['booking_ref']?.toString() ??
        scannedJson?['booking_ref']?.toString() ??
        scannedJson?['reference_number']?.toString() ??
        'N/A';
    final String bookingStatus = data['booking_status']?.toString() ?? 'CONFIRMED';
    final String seatNumber = data['seat_number']?.toString() ??
        scannedJson?['seat']?.toString() ??
        'General';
    final String vesselName = data['vessel_name']?.toString() ??
        scannedJson?['vessel']?.toString() ??
        'Commercial Vessel';
    final String departureTime = data['departure_time']?.toString() ??
        scannedJson?['departure_time']?.toString() ??
        '07:30 AM';
    final String tripDate = data['trip_date']?.toString() ??
        scannedJson?['trip_date']?.toString() ??
        '';
    final String? boardingOpenTime = data['boarding_open_time']?.toString();
    final String? boardingCloseTime = data['boarding_close_time']?.toString();
    final String boardedAt = data['boarded_at']?.toString() ?? '';

    final String tripSchedule = tripDate.isNotEmpty
        ? '$tripDate · $departureTime'
        : departureTime;
    final String vesselSeat = seatNumber.toLowerCase().contains('seat')
        ? '$vesselName ($seatNumber)'
        : '$vesselName (Seat $seatNumber)';

    String? boardingWindowText;
    if (boardingOpenTime != null && boardingCloseTime != null) {
      boardingWindowText = '$boardingOpenTime - $boardingCloseTime';
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Badge Header (Green)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF10B981), width: 3),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'BOARDING APPROVED',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                passengerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),

              // Summary Ticket Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildModalRow('Passenger', passengerName),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Reference #', refNumber, isMonospace: true, isSelectable: true, isHighlight: true),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Ticket Status', bookingStatus, valueWidget: _buildStatusBadge(bookingStatus)),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Departure Time', departureTime),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Trip Schedule', tripSchedule),
                    if (boardingWindowText != null) ...[
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildModalRow('Boarding Window', boardingWindowText),
                    ],
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    _buildModalRow('Vessel / Seat', vesselSeat),
                    if (boardedAt.isNotEmpty) ...[
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildModalRow('Boarded At', boardedAt, isSmall: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tap to Scan Next Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (mounted) {
                      setState(() => _isProcessing = false);
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  label: const Text(
                    'TAP TO SCAN NEXT',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  void _showErrorModal({
    required String status,
    required String message,
    required String referenceNumber,
    String? scannedPassengerName,
    Map<String, dynamic>? scannedJson,
    Map<String, dynamic>? data,
  }) {
    // 1. Sanitize message: never render raw JSON braces {}
    String cleanMessage = message.trim();
    if (cleanMessage.contains('{') && cleanMessage.contains('}')) {
      cleanMessage = 'Ticket reference $referenceNumber was not found in the system.';
    } else if (cleanMessage.startsWith("Ticket reference '") && cleanMessage.endsWith("' not found.")) {
      cleanMessage = 'Ticket reference $referenceNumber was not found in the system.';
    }

    // 2. Explicitly extract reference_number or booking_ref from both parsed QR JSON and API response
    final String cleanRefNumber = data?['reference_number']?.toString() ??
        data?['booking_ref']?.toString() ??
        scannedJson?['booking_ref']?.toString() ??
        scannedJson?['reference_number']?.toString() ??
        referenceNumber;

    final String passengerName = data?['passenger_name']?.toString() ??
        scannedJson?['passenger_name']?.toString() ??
        scannedPassengerName ??
        'Unknown / Unregistered';

    final String? tripDate = data?['trip_date']?.toString() ??
        scannedJson?['trip_date']?.toString();

    final String? departureTime = data?['departure_time']?.toString() ??
        scannedJson?['departure_time']?.toString();

    final String? boardingOpenTime = data?['boarding_open_time']?.toString();
    final String? boardingCloseTime = data?['boarding_close_time']?.toString();

    final String? vesselName = data?['vessel_name']?.toString() ??
        scannedJson?['vessel']?.toString() ??
        scannedJson?['vessel_name']?.toString();

    final String? seatNumber = data?['seat_number']?.toString() ??
        scannedJson?['seat']?.toString() ??
        scannedJson?['seat_number']?.toString();

    final String? boardedAt = data?['boarded_at']?.toString();

    // Determine booking status
    final String rawStatusUpper = status.toUpperCase();
    final String? apiBookingStatus = data?['booking_status']?.toString();
    final String? bookingStatus = apiBookingStatus ??
        (rawStatusUpper == 'STATUS_PENDING'
            ? 'PENDING'
            : (rawStatusUpper == 'STATUS_CANCELLED'
                ? 'CANCELLED'
                : (status == 'BOARDED_SUCCESS' || status == 'ALREADY_BOARDED' || status == 'TOO_EARLY' || status == 'BOARDING_CLOSED'
                    ? 'CONFIRMED'
                    : null)));

    // Color theme resolution based on status
    final bool isTooEarly = status == 'TOO_EARLY';
    final bool isPending = rawStatusUpper == 'STATUS_PENDING' || (bookingStatus?.toUpperCase() == 'PENDING');
    final bool isCancelled = rawStatusUpper == 'STATUS_CANCELLED' || (bookingStatus?.toUpperCase() == 'CANCELLED') || (bookingStatus?.toUpperCase() == 'CANCELED');

    Color iconBgColor;
    Color iconBorderColor;
    Color primaryThemeColor;
    IconData statusIcon;
    String statusDisplayTitle;
    Color cardBgColor;
    Color cardBorderColor;

    if (isPending) {
      iconBgColor = const Color(0xFFFFF3E0);
      iconBorderColor = const Color(0xFFFF9800);
      primaryThemeColor = const Color(0xFFE65100);
      statusIcon = Icons.hourglass_top_rounded;
      statusDisplayTitle = 'TICKET IS PENDING';
      cardBgColor = const Color(0xFFFFFBEB);
      cardBorderColor = const Color(0xFFFDE68A);
    } else if (isCancelled) {
      iconBgColor = const Color(0xFFFEE2E2);
      iconBorderColor = const Color(0xFFEF4444);
      primaryThemeColor = const Color(0xFFC62828);
      statusIcon = Icons.cancel_rounded;
      statusDisplayTitle = 'TICKET CANCELLED';
      cardBgColor = const Color(0xFFFFF0F0);
      cardBorderColor = const Color(0xFFFFCDD2);
    } else if (isTooEarly) {
      iconBgColor = const Color(0xFFFEF3C7);
      iconBorderColor = const Color(0xFFF59E0B);
      primaryThemeColor = const Color(0xFFD97706);
      statusIcon = Icons.schedule_rounded;
      statusDisplayTitle = 'BOARDING NOT OPEN YET';
      cardBgColor = const Color(0xFFFFFBEB);
      cardBorderColor = const Color(0xFFFDE68A);
    } else {
      iconBgColor = const Color(0xFFFEE2E2);
      iconBorderColor = const Color(0xFFEF4444);
      primaryThemeColor = const Color(0xFFDC2626);
      statusIcon = Icons.close_rounded;
      statusDisplayTitle = (status == 'TICKET_NOT_FOUND' || status == 'NOT_FOUND')
          ? 'TICKET NOT FOUND'
          : status.replaceAll('_', ' ');
      cardBgColor = const Color(0xFFFFF0F0);
      cardBorderColor = const Color(0xFFFFCDD2);
    }

    // Format Trip Schedule & Boarding Window
    String? tripScheduleText;
    if (tripDate != null && tripDate.isNotEmpty && departureTime != null && departureTime.isNotEmpty) {
      tripScheduleText = '$tripDate · $departureTime';
    } else if (departureTime != null && departureTime.isNotEmpty) {
      tripScheduleText = departureTime;
    } else if (tripDate != null && tripDate.isNotEmpty) {
      tripScheduleText = tripDate;
    }

    String? boardingWindowText;
    if (boardingOpenTime != null && boardingCloseTime != null) {
      boardingWindowText = '$boardingOpenTime - $boardingCloseTime';
    }

    // Format Vessel / Seat: e.g. "BANGKA 419 (Seat 1D)"
    String? vesselSeatText;
    if (vesselName != null && vesselName.isNotEmpty && seatNumber != null && seatNumber.isNotEmpty) {
      vesselSeatText = seatNumber.toLowerCase().contains('seat')
          ? '$vesselName ($seatNumber)'
          : '$vesselName (Seat $seatNumber)';
    } else if (vesselName != null && vesselName.isNotEmpty) {
      vesselSeatText = vesselName;
    } else if (seatNumber != null && seatNumber.isNotEmpty) {
      vesselSeatText = seatNumber.toLowerCase().contains('seat') ? seatNumber : 'Seat $seatNumber';
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Alert Icon (Orange for PENDING, Red for CANCELLED, Amber for TOO_EARLY)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: iconBorderColor, width: 3),
                ),
                child: Icon(
                  statusIcon,
                  color: primaryThemeColor,
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                statusDisplayTitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryThemeColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cleanMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // Passenger & Reference Info Card (Color-coded)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    _buildModalRow('Passenger', passengerName),
                    const SizedBox(height: 8),
                    _buildModalRow(
                      'Reference #',
                      cleanRefNumber,
                      isMonospace: true,
                      isSelectable: true,
                      isHighlight: true,
                    ),
                    if (bookingStatus != null && bookingStatus.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildModalRow(
                        'Ticket Status',
                        bookingStatus,
                        valueWidget: _buildStatusBadge(bookingStatus),
                      ),
                    ],
                    if (departureTime != null && departureTime.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildModalRow('Departure Time', departureTime),
                    ],
                    if (boardingWindowText != null && boardingWindowText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildModalRow('Boarding Window', boardingWindowText),
                    ],
                    if (tripScheduleText != null && tripScheduleText.isNotEmpty && tripScheduleText != departureTime) ...[
                      const SizedBox(height: 8),
                      _buildModalRow('Trip Schedule', tripScheduleText),
                    ],
                    if (vesselSeatText != null && vesselSeatText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildModalRow('Vessel / Seat', vesselSeatText),
                    ],
                    if (boardedAt != null && boardedAt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildModalRow('First Scanned', boardedAt),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Scan Next Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (mounted) {
                      setState(() => _isProcessing = false);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'SCAN NEXT TICKET',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryThemeColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  Widget _buildStatusBadge(String status) {
    final cleanStatus = status.trim().toUpperCase();
    Color textColor;
    Color bgColor;
    IconData iconData;

    if (cleanStatus == 'CONFIRMED') {
      textColor = const Color(0xFF2E7D32);
      bgColor = const Color(0xFFE8F5E9);
      iconData = Icons.check_circle_rounded;
    } else if (cleanStatus == 'PENDING') {
      textColor = const Color(0xFFE65100);
      bgColor = const Color(0xFFFFF3E0);
      iconData = Icons.hourglass_top_rounded;
    } else if (cleanStatus == 'CANCELLED' || cleanStatus == 'CANCELED') {
      textColor = const Color(0xFFC62828);
      bgColor = const Color(0xFFFFEBEE);
      iconData = Icons.cancel_rounded;
    } else {
      textColor = const Color(0xFF475569);
      bgColor = const Color(0xFFF1F5F9);
      iconData = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            cleanStatus,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalRow(
    String label,
    String value, {
    Widget? valueWidget,
    bool isMonospace = false,
    bool isHighlight = false,
    bool isBadge = false,
    bool isSelectable = false,
    bool isSmall = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: valueWidget != null
              ? Align(
                  alignment: Alignment.centerRight,
                  child: valueWidget,
                )
              : (isBadge
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFBF1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    )
                  : (isSelectable
                      ? SelectableText(
                          value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: isSmall ? 11 : (isHighlight ? 14 : 13),
                            fontFamily: isMonospace ? 'monospace' : null,
                            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w700,
                            color: isHighlight ? const Color(0xFF0F766E) : const Color(0xFF0F172A),
                          ),
                        )
                      : Text(
                          value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: isSmall ? 11 : 13,
                            fontFamily: isMonospace ? 'monospace' : null,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ))),
        ),
      ],
    );
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Manual Reference Entry', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter ticket reference number if the physical QR code is damaged or unreadable.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g., SP-20260909-0001',
                  labelText: 'Reference Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = textController.text.trim();
                Navigator.pop(ctx);
                if (code.isNotEmpty) {
                  setState(() => _isProcessing = true);
                  _verifyTicket(referenceNumber: code);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.mintGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Verify Ticket'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the scanner station?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ApiService.clearAuthHeader();
      await TokenStorageService.deleteToken();
      await PassengerSession.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffName = PassengerSession.name.isNotEmpty 
        ? PassengerSession.name 
        : 'Port Staff';
    final portName = PassengerSession.assignedPort.isNotEmpty 
        ? PassengerSession.assignedPort 
        : 'Surigao Port Terminal';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_rounded, size: 16, color: Color(0xFF2DD4BF)),
                const SizedBox(width: 6),
                Text(
                  staffName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '📍 $portName',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Manual Code Entry',
            icon: const Icon(Icons.dialpad_rounded, color: Colors.white),
            onPressed: _showManualEntryDialog,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171)),
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Full-screen Camera Viewfinder
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
          ),

          // 2. Translucent Camera Overlay Frame with Targeting Reticle
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),

          // 3. Clear Scanning Window
          Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isProcessing 
                    ? const Color(0xFFF59E0B) 
                    : const Color(0xFF10B981),
                width: 3.0,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_isProcessing 
                      ? const Color(0xFFF59E0B) 
                      : const Color(0xFF10B981)).withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Corner targeting marks
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 4),
                        left: BorderSide(color: Colors.white, width: 4),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 4),
                        right: BorderSide(color: Colors.white, width: 4),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 4),
                        left: BorderSide(color: Colors.white, width: 4),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white, width: 4),
                        right: BorderSide(color: Colors.white, width: 4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Instructional Notice
          Positioned(
            top: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_rounded, color: Color(0xFF2DD4BF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _isProcessing 
                        ? 'Verifying Ticket...' 
                        : 'Align Passenger QR Code inside box',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Flash Toggle & Manual Entry Bottom Toolbar
          Positioned(
            bottom: 36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flash / Torch Button
                FloatingActionButton.small(
                  heroTag: 'torchBtn',
                  backgroundColor: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white24,
                  foregroundColor: _isTorchOn ? Colors.black : Colors.white,
                  onPressed: () async {
                    await _scannerController.toggleTorch();
                    setState(() => _isTorchOn = !_isTorchOn);
                  },
                  child: Icon(
                    _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  ),
                ),
                const SizedBox(width: 20),

                // Manual Entry Button
                ElevatedButton.icon(
                  onPressed: _showManualEntryDialog,
                  icon: const Icon(Icons.keyboard_rounded, size: 18),
                  label: const Text('ENTER CODE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Camera Switch Button
                FloatingActionButton.small(
                  heroTag: 'cameraSwitchBtn',
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                  onPressed: () => _scannerController.switchCamera(),
                  child: const Icon(Icons.cameraswitch_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
