import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../app_navigator.dart';
import '../../models/passenger_booking_models.dart';
import '../../models/route_fare.dart';
import '../../models/schedule.dart';
import '../../services/api_exception.dart';
import '../../services/passenger_data_service.dart';
import '../../services/passenger_session.dart';
import '../../services/seat_map_service.dart';
import '../../widgets/app_palette.dart';
import '../passenger_home_screen.dart';
import 'steps/checkout_step_details.dart';
import 'steps/checkout_step_payment.dart';
import 'steps/checkout_step_seat_map.dart';
import 'paymongo_webview_screen.dart';

/// Parent coordinator and shared state container for the booking checkout flow.
/// Orchestrates stepper navigation, lifecycle timers, API polling, and submission.
class BookingCheckoutScreen extends StatefulWidget {
  const BookingCheckoutScreen({super.key, required this.schedule});

  static const String routeName = '/booking-checkout';

  final Schedule schedule;

  @override
  State<BookingCheckoutScreen> createState() => _BookingCheckoutScreenState();
}

class _BookingCheckoutScreenState extends State<BookingCheckoutScreen>
    with WidgetsBindingObserver, RouteAware {
  // ─── Multi-step Navigation State ──────────────────────────────────────────
  int _currentStep = 0; // 0: Details, 1: Seat Map, 2: Payment & Review

  // ─── Seat Count State ─────────────────────────────────────────────────────
  int _regularCount = 1;
  int _studentCount = 0;
  int _seniorCount = 0;

  // ─── Dynamic Passenger Data ───────────────────────────────────────────────
  final List<PassengerDetail> _passengers = [];

  // ─── Seat Map State & Service ─────────────────────────────────────────────
  final List<VesselSeat> _seats = [];
  int _activePassengerIndex = 0;

  final SeatMapService _seatMapService = SeatMapService();
  StreamSubscription<List<dynamic>>? _seatMapSubscription;

  // ─── Hold Countdown Timer (15:00 mins) ────────────────────────────────────
  Timer? _holdTimer;
  int _holdSecondsRemaining = 900;

  // ─── Payment Gateway Selection ────────────────────────────────────────────
  String _selectedPaymentId = 'paymongo_gcash';

  static const List<PaymentMethodOption> _paymentMethods = [
    PaymentMethodOption(
      id: 'paymongo_gcash',
      name: 'GCash / QR Ph (PayMongo)',
      subtitle: 'Instant dynamic QR payment via GCash or banking app',
      icon: Icons.qr_code_scanner_rounded,
      badge: 'Dynamic QR',
    ),
  ];

  // ─── Pricing & Live API State ─────────────────────────────────────────────
  RouteFare _fare = const RouteFare();
  bool _isLoadingFares = true;
  bool _isSubmitting = false;
  String? _fareError;
  Timer? _farePollTimer;

  final PassengerDataService _dataService = const PassengerDataService();

  int get _totalSeats => _regularCount + _studentCount + _seniorCount;

  int get _totalRows => _seats.isEmpty
      ? 8
      : _seats.map((s) => s.row).fold<int>(1, (max, r) => r > max ? r : max);

  double get _totalPrice =>
      (_regularCount * _fare.regular) +
      (_studentCount * _fare.student) +
      (_seniorCount * _fare.senior);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _syncPassengerForms();
    _generateSeatMap();
    _startHoldCountdown();

    // Listen to reactive seat map stream
    _seatMapSubscription = _seatMapService.seatMapStream.listen((rawMap) {
      if (mounted) {
        _applyBackendSeatMap(rawMap);
      }
    });

    _loadFares();
    _farePollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _loadFares(silent: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _farePollTimer?.cancel();
    _seatMapSubscription?.cancel();
    _seatMapService.dispose();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);

    for (final p in _passengers) {
      p.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFares(silent: true);
      if (_currentStep == 1) {
        _seatMapService.resumePolling();
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _seatMapService.pausePolling();
    }
  }

  @override
  void didPushNext() {
    _seatMapService.pausePolling();
  }

  @override
  void didPopNext() {
    if (_currentStep == 1) {
      _seatMapService.resumePolling();
    }
  }

  // ─── Timer Logic ──────────────────────────────────────────────────────────

  void _startHoldCountdown() {
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_holdSecondsRemaining > 0) {
        setState(() {
          _holdSecondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedHoldTime {
    final minutes = (_holdSecondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_holdSecondsRemaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ─── Seat Map Generator & Live Synchronizer ─────────────────────────────────

  void _generateSeatMap({List<dynamic>? backendSeatMap, int? capacity}) {
    final rawMap = backendSeatMap ?? widget.schedule.seatMap;
    final boatCapacity = capacity ?? widget.schedule.capacity;

    if (rawMap.isNotEmpty) {
      _applyBackendSeatMap(rawMap);
      return;
    }

    _seats.clear();
    final columns = ['A', 'B', 'C', 'D', 'E'];
    final rows = (boatCapacity / 5).ceil();
    int count = 0;

    for (int r = 1; r <= rows; r++) {
      for (final col in columns) {
        count++;
        if (count > boatCapacity) break;
        final code = '$r$col';
        _seats.add(
          VesselSeat(
            seatNumber: code,
            row: r,
            column: col,
            status: 'available',
            isBooked: false,
          ),
        );
      }
    }

    final available = widget.schedule.availableSeats;
    if (available < boatCapacity && _seats.isNotEmpty) {
      final neededBooked = boatCapacity - available;
      final seed = widget.schedule.id.hashCode;
      final shuffled = List<VesselSeat>.from(_seats)..shuffle(Random(seed));
      for (int i = 0; i < neededBooked && i < shuffled.length; i++) {
        final targetSeatNumber = shuffled[i].seatNumber;
        final idx = _seats.indexWhere((s) => s.seatNumber == targetSeatNumber);
        if (idx != -1) {
          _seats[idx] = VesselSeat(
            seatNumber: _seats[idx].seatNumber,
            row: _seats[idx].row,
            column: _seats[idx].column,
            status: 'booked',
            isBooked: true,
          );
        }
      }
    }
  }

  void _applyBackendSeatMap(List<dynamic> rawMap) {
    final passengerSelections = <String, int>{};
    for (final p in _passengers) {
      if (p.assignedSeat != null && p.assignedSeat!.isNotEmpty) {
        passengerSelections[p.assignedSeat!] = p.index;
      }
    }

    final newSeats = <VesselSeat>[];
    for (final item in rawMap) {
      if (item is Map) {
        final seat = VesselSeat.fromJson(Map<String, dynamic>.from(item));
        final assignedIndex = passengerSelections[seat.seatNumber];
        if (assignedIndex != null) {
          if (seat.isBooked) {
            final p = _passengers.firstWhere(
              (p) => p.index == assignedIndex,
              orElse: () => _passengers.first,
            );
            if (p.assignedSeat == seat.seatNumber) {
              p.assignedSeat = null;
            }
          } else {
            seat.assignedPassengerIndex = assignedIndex;
          }
        }
        newSeats.add(seat);
      }
    }

    // Client-side synchronization guarantee:
    // If backend seat map has fewer booked seats than (capacity - availableSeats),
    // mark random unbooked seats as booked so available count strictly matches admin setting
    final boatCapacity = widget.schedule.capacity;
    final available = widget.schedule.availableSeats;
    final targetBooked = boatCapacity - available;
    final currentBooked = newSeats.where((s) => s.isBooked).length;
    if (targetBooked > currentBooked) {
      final needed = targetBooked - currentBooked;
      final seed = widget.schedule.id.hashCode;
      final unbooked = newSeats.where((s) => !s.isBooked && s.assignedPassengerIndex == null).toList()
        ..shuffle(Random(seed));
      for (int i = 0; i < needed && i < unbooked.length; i++) {
        final seatNum = unbooked[i].seatNumber;
        final idx = newSeats.indexWhere((s) => s.seatNumber == seatNum);
        if (idx != -1) {
          newSeats[idx] = VesselSeat(
            seatNumber: newSeats[idx].seatNumber,
            row: newSeats[idx].row,
            column: newSeats[idx].column,
            status: 'booked',
            isBooked: true,
          );
        }
      }
    }

    if (newSeats.isNotEmpty && mounted) {
      setState(() {
        _seats.clear();
        _seats.addAll(newSeats);
      });
    }
  }

  // ─── Dynamic Passenger Forms Synchronization ──────────────────────────────

  void _syncPassengerForms() {
    if (_passengers.isEmpty) {
      _passengers.add(
        PassengerDetail(
          index: 1,
          category: 'regular',
          initialGivenNames: '',
          initialLastName: '',
          isExpanded: true,
        ),
      );
    }

    _reconcileCategory('regular', _regularCount);
    _reconcileCategory('student', _studentCount);
    _reconcileCategory('senior', _seniorCount);

    _reindexPassengers();
  }

  void _reconcileCategory(String category, int targetCount) {
    int current = _passengers.where((p) => p.category == category).length;
    while (current < targetCount) {
      _passengers.add(
        PassengerDetail(
          index: _passengers.length + 1,
          category: category,
          initialGivenNames: '',
          initialLastName: '',
          initialIdNumber: '',
          isExpanded: true,
        ),
      );
      current++;
    }
    while (current > targetCount) {
      final idx = _passengers.lastIndexWhere((p) => p.category == category);
      if (idx != -1) {
        final removed = _passengers.removeAt(idx);
        _unassignPassengerSeat(removed.index);
        removed.dispose();
        current--;
      } else {
        break;
      }
    }
  }

  void _reindexPassengers() {
    for (int i = 0; i < _passengers.length; i++) {
      final oldIndex = _passengers[i].index;
      final newIndex = i + 1;
      _passengers[i].index = newIndex;
      if (oldIndex != newIndex) {
        for (final seat in _seats) {
          if (seat.assignedPassengerIndex == oldIndex) {
            seat.assignedPassengerIndex = newIndex;
          }
        }
      }
    }
    if (_activePassengerIndex >= _passengers.length) {
      _activePassengerIndex = _passengers.isNotEmpty ? _passengers.length - 1 : 0;
    }
  }

  void _unassignPassengerSeat(int passengerIndex) {
    for (final seat in _seats) {
      if (seat.assignedPassengerIndex == passengerIndex) {
        seat.assignedPassengerIndex = null;
      }
    }
  }

  // ─── Seat Tap Handling ────────────────────────────────────────────────────

  void _onSeatTapped(VesselSeat seat) {
    _seatMapService.recordInteraction();
    if (seat.isBooked) return;

    final activePassenger = _passengers.isNotEmpty && _activePassengerIndex < _passengers.length
        ? _passengers[_activePassengerIndex]
        : null;
    if (activePassenger == null) return;

    setState(() {
      if (seat.assignedPassengerIndex == activePassenger.index) {
        seat.assignedPassengerIndex = null;
        activePassenger.assignedSeat = null;
        return;
      }

      if (seat.assignedPassengerIndex != null) {
        final other = _passengers.firstWhere(
          (p) => p.index == seat.assignedPassengerIndex,
          orElse: () => activePassenger,
        );
        other.assignedSeat = null;
      }

      for (final s in _seats) {
        if (s.assignedPassengerIndex == activePassenger.index) {
          s.assignedPassengerIndex = null;
        }
      }

      seat.assignedPassengerIndex = activePassenger.index;
      activePassenger.assignedSeat = seat.code;

      final nextUnassigned = _passengers.indexWhere(
        (p) => p.assignedSeat == null || p.assignedSeat!.isEmpty,
      );
      if (nextUnassigned != -1) {
        _activePassengerIndex = nextUnassigned;
      }
    });
  }

  // ─── Counter Actions ──────────────────────────────────────────────────────

  void _incrementCategory(String type) {
    if (_totalSeats >= widget.schedule.availableSeats) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot exceed remaining available seats (${widget.schedule.availableSeats}).',
          ),
        ),
      );
      return;
    }

    setState(() {
      if (type == 'regular') _regularCount++;
      if (type == 'student') _studentCount++;
      if (type == 'senior') _seniorCount++;

      final newPassenger = PassengerDetail(
        index: _passengers.length + 1,
        category: type,
        initialGivenNames: '',
        initialLastName: '',
        initialIdNumber: '',
        isExpanded: true,
      );

      _passengers.add(newPassenger);
    });
  }

  void _decrementCategory(String type) {
    if (_totalSeats <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 1 seat must be selected.')),
      );
      return;
    }

    final targetIndex = _passengers.lastIndexWhere((p) => p.category == type);
    if (targetIndex == -1) return;

    setState(() {
      if (type == 'regular' && _regularCount > 0) _regularCount--;
      if (type == 'student' && _studentCount > 0) _studentCount--;
      if (type == 'senior' && _seniorCount > 0) _seniorCount--;

      final removed = _passengers.removeAt(targetIndex);
      _unassignPassengerSeat(removed.index);
      removed.dispose();

      _reindexPassengers();
    });
  }

  // ─── Step Transitions & Validations ───────────────────────────────────────

  void _goToStep(int step) {
    if (step == 1) {
      // Validate Step 1
      for (final p in _passengers) {
        if (!p.isComplete) {
          setState(() {
            p.isExpanded = true;
          });
          final missingId = (p.category != 'regular') && (p.idPhotoPath == null || p.idPhotoPath!.trim().isEmpty);
          final errorMsg = missingId
              ? 'Please attach a valid ID photo for Passenger ${p.index} (${p.categoryLabel}) to claim the discount.'
              : 'Please complete the name for Passenger ${p.index} (${p.categoryLabel}).';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
      _seatMapService.startPolling(widget.schedule.id);
    } else {
      _seatMapService.stopPolling();
    }

    if (step == 2) {
      // Validate Step 2: Ensure all passengers have assigned seats
      final unassigned = _passengers.where(
        (p) => p.assignedSeat == null || p.assignedSeat!.isEmpty,
      );
      if (unassigned.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please assign seats to all passengers (${unassigned.length} remaining).',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() {
      _currentStep = step;
    });
  }

  // ─── Live Fares API ───────────────────────────────────────────────────────

  Future<void> _loadFares({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoadingFares = true;
        _fareError = null;
      });
    }

    try {
      final routeStr = '${widget.schedule.from} → ${widget.schedule.to}';
      final fare = await _dataService.fetchFareForRoute(
        routeStr,
        from: widget.schedule.from,
        to: widget.schedule.to,
      );
      if (!mounted) return;
      setState(() {
        _fare = fare;
        _isLoadingFares = false;
        _fareError = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingFares = false;
        if (!silent) _fareError = error.message;
      });
    }
  }

  // ─── Final Booking Submission ─────────────────────────────────────────────

  Future<void> _submitBooking() async {
    if (!widget.schedule.isBookableInManila) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This trip has already departed and cannot be booked.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final seatBreakdown = _passengers.asMap().entries.map((entry) {
      final idx = entry.key;
      final p = entry.value;
      double individualFare = _fare.regular;
      final cat = p.category.toLowerCase();
      if (cat == 'student') {
        individualFare = _fare.student > 0 ? _fare.student : (_fare.regular * 0.80);
      } else if (cat == 'senior' || cat == 'pwd') {
        individualFare = _fare.senior > 0 ? _fare.senior : (_fare.regular * 0.80);
      }
      return {
        'passenger_id': 'P${idx + 1}',
        'passenger_name': p.fullName,
        'seat': p.assignedSeat ?? '',
        'category': p.category,
        'individual_fare': individualFare,
      };
    }).toList();

    final seatList = _passengers.asMap().entries.map((entry) {
      final idx = entry.key;
      final p = entry.value;
      final fareNum = (seatBreakdown[idx]['individual_fare'] as double?) ?? _fare.regular;
      return '${p.fullName} (Seat #${p.assignedSeat} - ${p.category} - ₱${fareNum.toStringAsFixed(2)})';
    }).join(', ');

    final discountNotes = _passengers
        .where((p) => p.idNumberController.text.trim().isNotEmpty)
        .map((p) => 'ID ${p.fullName}: ${p.idNumberController.text.trim()}')
        .join('; ');

    final primaryContactName = PassengerSession.name.isNotEmpty
        ? PassengerSession.name
        : (_passengers.isNotEmpty ? _passengers.first.fullName : 'Passenger');
    final primaryContactPhone = PassengerSession.phone;
    final primaryEmail = PassengerSession.email;

    final fullNotes = [
      'Seats: $seatList',
      if (discountNotes.isNotEmpty) 'Discounts: $discountNotes',
      if (primaryContactPhone.isNotEmpty) 'Contact: $primaryContactName ($primaryContactPhone)',
      'Payment: ${_paymentMethods.firstWhere((m) => m.id == _selectedPaymentId, orElse: () => _paymentMethods.first).name}',
      'Total: ₱${_totalPrice.toStringAsFixed(2)}',
    ].join(' | ');

    final chosenSeatNumbers = _passengers
        .map((p) => p.assignedSeat)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();

    final Map<int, String> passengerIdPhotos = {};
    for (int i = 0; i < _passengers.length; i++) {
      final p = _passengers[i];
      if (p.idPhotoPath != null && p.idPhotoPath!.trim().isNotEmpty) {
        passengerIdPhotos[i] = p.idPhotoPath!.trim();
      }
    }

    try {
      final session = await _dataService.createPayMongoCheckoutSession(
        scheduleId: widget.schedule.id,
        passengerName: primaryContactName,
        seatCount: _totalSeats,
        amountCollected: _totalPrice,
        notes: fullNotes,
        seatNumbers: chosenSeatNumbers,
        seatBreakdown: seatBreakdown,
        passengerIdPhotos: passengerIdPhotos,
        passengerId: PassengerSession.passengerId > 0 ? PassengerSession.passengerId : null,
        contactNumber: primaryContactPhone,
        email: primaryEmail,
      );

      if (!mounted) return;

      final checkoutUrl = session['checkout_url'] as String? ?? '';
      final bookingData = (session['booking'] is Map)
          ? Map<String, dynamic>.from(session['booking'])
          : <String, dynamic>{};
      final refNum = bookingData['reference_number']?.toString() ?? 'PENDING';
      final hasDiscounts = _studentCount > 0 || _seniorCount > 0 || (bookingData['has_discounts'] == true);

      if (checkoutUrl.isEmpty) {
        throw ApiException('Failed to retrieve PayMongo payment URL.');
      }

      // Launch PayMongo dynamic QR in WebView
      final result = await Navigator.of(context).push<PaymentResult>(
        MaterialPageRoute(
          builder: (ctx) => PayMongoWebViewScreen(
            checkoutUrl: checkoutUrl,
            referenceNumber: refNum,
            totalAmount: _totalPrice,
          ),
        ),
      );

      if (!mounted) return;

      if (result == PaymentResult.success) {
        if (hasDiscounts) {
          // Holding State Dialog for Discounted Bookings
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.only(top: 26.0, left: 20.0, right: 20.0, bottom: 8.0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              actionsPadding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 24.0),
              actionsAlignment: MainAxisAlignment.center,
              title: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment Received!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'HOLDING STATE • ID VERIFICATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reference #$refNum',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppPalette.darkText,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trip: ${widget.schedule.from} → ${widget.schedule.to}\n'
                    'Seats: ${_passengers.map((p) => 'Seat #${p.assignedSeat}').join(', ')}\n'
                    'Amount Paid: ₱${_totalPrice.toStringAsFixed(2)}\n'
                    'Payment: GCash / QR Ph (PayMongo)',
                    style: const TextStyle(height: 1.45, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'ℹ️ Because your booking includes discounted tickets (Student/Senior/PWD), our port administrators must review your uploaded ID photos. Once approved, your Boarding Pass QR will be generated.\n\n🛡️ If your ID cannot be verified, your payment will be automatically refunded to your GCash account.',
                      style: TextStyle(fontSize: 12, height: 1.4, color: AppPalette.darkText),
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        PassengerHomeScreen.routeName,
                        (route) => false,
                        arguments: {'tabIndex': 1},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'VIEW MY BOOKINGS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Regular Booking Auto-Confirmed Dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.only(top: 28.0, left: 20.0, right: 20.0, bottom: 8.0),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              actionsPadding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 24.0),
              actionsAlignment: MainAxisAlignment.center,
              title: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppPalette.mintGreen, size: 28),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking Confirmed!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reference #$refNum',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppPalette.mintGreen,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Trip: ${widget.schedule.from} → ${widget.schedule.to}\n'
                    'Seats: ${_passengers.map((p) => 'Seat #${p.assignedSeat}').join(', ')}\n'
                    'Total Paid: ₱${_totalPrice.toStringAsFixed(2)}\n'
                    'Payment: GCash / QR Ph (PayMongo)',
                    style: const TextStyle(height: 1.45, fontSize: 13.5),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your payment was verified via PayMongo and your Boarding Pass QR code is ready.',
                    style: TextStyle(fontSize: 12.5, color: Colors.black54),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        PassengerHomeScreen.routeName,
                        (route) => false,
                        arguments: {'tabIndex': 1},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.mintGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'VIEW MY BOOKINGS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      } else if (result == PaymentResult.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was cancelled. Your seat reservation has not been finalized.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (result == PaymentResult.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment could not be completed. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // ─── Build Method ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Booking Checkout'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
                if (_currentStep == 1) {
                  _seatMapService.startPolling(widget.schedule.id);
                } else {
                  _seatMapService.stopPolling();
                }
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: _isLoadingFares
          ? const Center(child: CircularProgressIndicator(color: AppPalette.mintGreen))
          : _fareError != null && _fare == const RouteFare()
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_fareError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadFares,
                          child: const Text('RETRY'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // Stepper Progress Header
                      _buildStepperHeader(),

                      // Step Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                          child: _buildCurrentStepContent(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ─── Visual Stepper Header ────────────────────────────────────────────────

  Widget _buildStepperHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          _buildStepNode(0, '1. Details'),
          _buildStepConnector(0),
          _buildStepNode(1, '2. Seat Map'),
          _buildStepConnector(1),
          _buildStepNode(2, '3. Payment'),
        ],
      ),
    );
  }

  Widget _buildStepNode(int stepIndex, String title) {
    final bool isActive = _currentStep == stepIndex;
    final bool isPassed = _currentStep > stepIndex;

    return GestureDetector(
      onTap: () {
        if (stepIndex < _currentStep) {
          setState(() {
            _currentStep = stepIndex;
            if (_currentStep == 1) {
              _seatMapService.startPolling(widget.schedule.id);
            } else {
              _seatMapService.stopPolling();
            }
          });
        } else if (stepIndex > _currentStep) {
          _goToStep(stepIndex);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPassed
                  ? AppPalette.mintGreen
                  : isActive
                      ? AppPalette.mintGreen
                      : Colors.grey.shade200,
            ),
            child: Center(
              child: isPassed
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppPalette.darkText : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int stepIndex) {
    final bool isPassed = _currentStep > stepIndex;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: isPassed ? AppPalette.mintGreen : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return CheckoutStepDetails(
          schedule: widget.schedule,
          fare: _fare,
          regularCount: _regularCount,
          studentCount: _studentCount,
          seniorCount: _seniorCount,
          totalSeats: _totalSeats,
          totalPrice: _totalPrice,
          passengers: _passengers,
          onIncrementCategory: _incrementCategory,
          onDecrementCategory: _decrementCategory,
          onProceedToSeats: () => _goToStep(1),
          onPassengerFormUpdated: () => setState(() {}),
        );
      case 1:
        return ValueListenableBuilder<bool>(
          valueListenable: _seatMapService.isRefreshing,
          builder: (context, isRefreshing, _) {
            return CheckoutStepSeatMap(
              schedule: widget.schedule,
              passengers: _passengers,
              seats: _seats,
              activePassengerIndex: _activePassengerIndex,
              totalSeats: _totalSeats,
              totalRows: _totalRows,
              isRefreshing: isRefreshing,
              onManualRefresh: _seatMapService.manualRefresh,
              onActivePassengerChanged: (index) => setState(() => _activePassengerIndex = index),
              onSeatTapped: _onSeatTapped,
              onBackToDetails: () => setState(() {
                _currentStep = 0;
                _seatMapService.stopPolling();
              }),
              onProceedToPayment: () => _goToStep(2),
            );
          },
        );
      case 2:
      default:
        return CheckoutStepPayment(
          schedule: widget.schedule,
          fare: _fare,
          regularCount: _regularCount,
          studentCount: _studentCount,
          seniorCount: _seniorCount,
          totalPrice: _totalPrice,
          passengers: _passengers,
          formattedHoldTime: _formattedHoldTime,
          paymentMethods: _paymentMethods,
          selectedPaymentId: _selectedPaymentId,
          isSubmitting: _isSubmitting,
          onPaymentMethodSelected: (id) => setState(() => _selectedPaymentId = id),
          onBackToSeats: () => setState(() {
            _currentStep = 1;
            _seatMapService.startPolling(widget.schedule.id);
          }),
          onConfirmAndPay: _submitBooking,
        );
    }
  }
}
