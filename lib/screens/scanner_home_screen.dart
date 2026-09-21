import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api_service.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../services/token_storage_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/app_card.dart';
import '../widgets/status_chip.dart';
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
      backgroundColor: AppPalette.transparent,
      builder: (ctx) {
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Badge Header (Green)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppPalette.success.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppPalette.success,
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'BOARDING APPROVED',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppPalette.success),
              ),
              const SizedBox(height: 6),
              Text(
                passengerName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Summary Ticket Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.of(context).canvas,
                  borderRadius: BorderRadius.circular(AppPalette.radiusMd),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildModalRow('Passenger', passengerName),
                    Divider(height: 14, color: AppColors.of(context).hairline),
                    _buildModalRow('Reference #', refNumber, isMonospace: true, isSelectable: true, isHighlight: true),
                    Divider(height: 14, color: AppColors.of(context).hairline),
                    _buildModalRow('Ticket Status', bookingStatus, valueWidget: _buildStatusBadge(bookingStatus)),
                    Divider(height: 14, color: AppColors.of(context).hairline),
                    _buildModalRow('Departure Time', departureTime),
                    Divider(height: 14, color: AppColors.of(context).hairline),
                    _buildModalRow('Trip Schedule', tripSchedule),
                    if (boardingWindowText != null) ...[
                      Divider(height: 14, color: AppColors.of(context).hairline),
                      _buildModalRow('Boarding Window', boardingWindowText),
                    ],
                    Divider(height: 14, color: AppColors.of(context).hairline),
                    _buildModalRow('Vessel / Seat', vesselSeat),
                    if (boardedAt.isNotEmpty) ...[
                      Divider(height: 14, color: AppColors.of(context).hairline),
                      _buildModalRow('Boarded At', boardedAt, isSmall: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tap to Scan Next Button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (mounted) {
                      setState(() => _isProcessing = false);
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  label: const Text('Tap to Scan Next',
                      overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.success,
                    foregroundColor: AppPalette.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppPalette.radiusMd),
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
    Color primaryThemeColor;
    IconData statusIcon;
    String statusDisplayTitle;
    Color cardBgColor;

    if (isPending) {
      iconBgColor = AppPalette.warning.withValues(alpha: .12);
      primaryThemeColor = AppPalette.warning;
      statusIcon = Icons.hourglass_top_rounded;
      statusDisplayTitle = 'TICKET IS PENDING';
      cardBgColor = AppPalette.warning.withValues(alpha: .12);
    } else if (isCancelled) {
      iconBgColor = AppPalette.danger.withValues(alpha: .12);
      primaryThemeColor = AppPalette.danger;
      statusIcon = Icons.cancel_rounded;
      statusDisplayTitle = 'TICKET CANCELLED';
      cardBgColor = AppPalette.danger.withValues(alpha: .12);
    } else if (isTooEarly) {
      iconBgColor = AppPalette.warning.withValues(alpha: .12);
      primaryThemeColor = AppPalette.warning;
      statusIcon = Icons.schedule_rounded;
      statusDisplayTitle = 'BOARDING NOT OPEN YET';
      cardBgColor = AppPalette.warning.withValues(alpha: .12);
    } else {
      iconBgColor = AppPalette.danger.withValues(alpha: .12);
      primaryThemeColor = AppPalette.danger;
      statusIcon = Icons.close_rounded;
      statusDisplayTitle = (status == 'TICKET_NOT_FOUND' || status == 'NOT_FOUND')
          ? 'TICKET NOT FOUND'
          : status.replaceAll('_', ' ');
      cardBgColor = AppPalette.danger.withValues(alpha: .12);
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
      backgroundColor: AppPalette.transparent,
      builder: (ctx) {
        return AppCard(
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
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: primaryThemeColor),
              ),
              const SizedBox(height: 8),
              Text(
                cleanMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),

              // Passenger & Reference Info Card (Color-coded)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(AppPalette.radiusMd),
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
                height: 44,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (mounted) {
                      setState(() => _isProcessing = false);
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text('Scan Next Ticket',
                      overflow: TextOverflow.ellipsis),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryThemeColor,
                    foregroundColor: AppPalette.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppPalette.radiusMd),
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
    final StatusTone tone;
    final IconData iconData;

    if (cleanStatus == 'CONFIRMED') {
      tone = StatusTone.success;
      iconData = Icons.check_circle_rounded;
    } else if (cleanStatus == 'PENDING') {
      tone = StatusTone.warning;
      iconData = Icons.hourglass_top_rounded;
    } else if (cleanStatus == 'CANCELLED' || cleanStatus == 'CANCELED') {
      tone = StatusTone.danger;
      iconData = Icons.cancel_rounded;
    } else {
      tone = StatusTone.info;
      iconData = Icons.info_rounded;
    }

    return StatusChip(label: cleanStatus, tone: tone, icon: iconData);
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
              color: AppColors.of(context).text2,
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
                          color: AppColors.of(context).tint,
                          borderRadius:
                              BorderRadius.circular(AppPalette.radiusPill),
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.of(context).onTint,
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
                            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w700,
                            color: isHighlight ? AppColors.of(context).onTint : AppColors.of(context).text,
                          ),
                        )
                      : Text(
                          value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: isSmall ? 11 : 13,
                            fontFamily: isMonospace ? 'monospace' : null,
                            fontWeight: FontWeight.w700,
                            color: AppColors.of(context).text,
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
          title: const Text('Manual Reference Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter ticket reference number if the physical QR code is damaged or unreadable.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'e.g., SP-20260909-0001',
                  labelText: 'Reference Number',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final code = textController.text.trim();
                Navigator.pop(ctx);
                if (code.isNotEmpty) {
                  setState(() => _isProcessing = true);
                  _verifyTicket(referenceNumber: code);
                }
              },
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
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out of the scanner station?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.danger,
              foregroundColor: AppPalette.white,
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
      backgroundColor: AppPalette.ink,
      appBar: AppBar(
        backgroundColor: AppPalette.ink,
        foregroundColor: AppPalette.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_rounded, size: 16, color: AppPalette.teal400),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    staffName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppPalette.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.place_rounded,
                    size: 14, color: AppPalette.darkText3),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    portName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppPalette.darkText2),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Manual Code Entry',
            icon: const Icon(Icons.dialpad_rounded, color: AppPalette.white),
            onPressed: _showManualEntryDialog,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded, color: AppPalette.danger),
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
                color: AppPalette.ink.withValues(alpha: 0.35),
              ),
            ),
          ),

          // 3. Clear Scanning Window
          Container(
            width: 270,
            height: 270,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppPalette.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: (_isProcessing 
                      ? AppPalette.warning 
                      : AppPalette.success).withValues(alpha: 0.25),
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
                        top: BorderSide(color: AppPalette.white, width: 4),
                        left: BorderSide(color: AppPalette.white, width: 4),
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
                        top: BorderSide(color: AppPalette.white, width: 4),
                        right: BorderSide(color: AppPalette.white, width: 4),
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
                        bottom: BorderSide(color: AppPalette.white, width: 4),
                        left: BorderSide(color: AppPalette.white, width: 4),
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
                        bottom: BorderSide(color: AppPalette.white, width: 4),
                        right: BorderSide(color: AppPalette.white, width: 4),
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
                color: AppPalette.ink.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(AppPalette.radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_rounded, color: AppPalette.teal400, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _isProcessing
                          ? 'Verifying Ticket...'
                          : 'Align Passenger QR Code inside box',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppPalette.white),
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
                  backgroundColor: _isTorchOn ? AppPalette.warning : AppPalette.white.withValues(alpha: .24),
                  foregroundColor: _isTorchOn ? AppPalette.ink : AppPalette.white,
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
                FilledButton.icon(
                  onPressed: _showManualEntryDialog,
                  icon: const Icon(Icons.keyboard_rounded, size: 18),
                  label: const Text('Enter Code'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.of(context).surface,
                    foregroundColor: AppColors.of(context).text,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppPalette.radiusPill),
                    ),
                    textStyle: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 20),

                // Camera Switch Button
                FloatingActionButton.small(
                  heroTag: 'cameraSwitchBtn',
                  backgroundColor: AppPalette.white.withValues(alpha: .24),
                  foregroundColor: AppPalette.white,
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
