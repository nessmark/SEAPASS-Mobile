import 'dart:async';

import 'package:flutter/material.dart';

import '../app_navigator.dart';
import '../models/passenger_booking_models.dart';
import '../models/route_fare.dart';
import '../models/schedule.dart';
import '../services/api_exception.dart';
import '../services/passenger_data_service.dart';
import '../services/passenger_session.dart';
import '../widgets/app_palette.dart';
import 'passenger_home_screen.dart';

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

  // ─── Seat Map State ───────────────────────────────────────────────────────
  final List<VesselSeat> _seats = [];
  int _activePassengerIndex = 0;

  // ─── Hold Countdown Timer (15:00 mins) ────────────────────────────────────
  Timer? _holdTimer;
  int _holdSecondsRemaining = 900;

  // ─── Payment Gateway Selection ────────────────────────────────────────────
  String _selectedPaymentId = 'gcash';

  static const List<PaymentMethodOption> _paymentMethods = [
    PaymentMethodOption(
      id: 'gcash',
      name: 'GCash',
      subtitle: 'Instant QR payment via GCash App',
      icon: Icons.account_balance_wallet_rounded,
      badge: 'Instant QR',
    ),
  ];

  // ─── Pricing & Live API State ─────────────────────────────────────────────
  RouteFare _fare = const RouteFare();
  bool _isLoadingFares = true;
  bool _isSubmitting = false;
  String? _fareError;
  Timer? _farePollTimer;
  Timer? _seatMapPollTimer;

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
    _loadLiveSeatMap();
    _startHoldCountdown();

    _loadFares();
    _farePollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _loadFares(silent: true);
    });

    _seatMapPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadLiveSeatMap(silent: true);
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
    _seatMapPollTimer?.cancel();
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
      _loadLiveSeatMap(silent: true);
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

    // Fallback: build seats based on actual boat capacity
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
  }

  void _applyBackendSeatMap(List<dynamic> rawMap) {
    // Preserve any existing user selections in current checkout session
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
            // Seat was booked by another user! Clear assignment
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

    if (newSeats.isNotEmpty && mounted) {
      setState(() {
        _seats.clear();
        _seats.addAll(newSeats);
      });
    }
  }

  Future<void> _loadLiveSeatMap({bool silent = false}) async {
    try {
      final data = await _dataService.fetchTripSeatMap(widget.schedule.id);
      if (!mounted) return;
      if (data.isNotEmpty && data['seat_map'] is List) {
        final rawMap = data['seat_map'] as List;
        _applyBackendSeatMap(rawMap);
      }
    } catch (_) {
      // Retain existing map on temporary network glitch
    }
  }

  // ─── Dynamic Passenger Forms Synchronization ──────────────────────────────

  void _syncPassengerForms() {
    if (_passengers.isEmpty) {
      final initialGiven = PassengerSession.name.isNotEmpty
          ? PassengerSession.name
          : '';
      _passengers.add(
        PassengerDetail(
          index: 1,
          category: 'regular',
          initialGivenNames: initialGiven,
          isExpanded: true,
        ),
      );
    }

    // Category-isolated reconciliation to guarantee no cross-type leakage or index overwriting
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
    if (seat.isBooked) return;

    final activePassenger = _passengers.isNotEmpty
        ? _passengers[_activePassengerIndex]
        : null;
    if (activePassenger == null) return;

    setState(() {
      // If tapping seat already assigned to active passenger, remove it
      if (seat.assignedPassengerIndex == activePassenger.index) {
        seat.assignedPassengerIndex = null;
        activePassenger.assignedSeat = null;
        return;
      }

      // If seat is assigned to another passenger, clear from that passenger
      if (seat.assignedPassengerIndex != null) {
        final other = _passengers.firstWhere(
          (p) => p.index == seat.assignedPassengerIndex,
          orElse: () => activePassenger,
        );
        other.assignedSeat = null;
      }

      // Unassign active passenger's old seat
      for (final s in _seats) {
        if (s.assignedPassengerIndex == activePassenger.index) {
          s.assignedPassengerIndex = null;
        }
      }

      // Assign to active passenger
      seat.assignedPassengerIndex = activePassenger.index;
      activePassenger.assignedSeat = seat.code;

      // Automatically advance to the next unseated passenger
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
      // 1. Increment specific passenger category count
      if (type == 'regular') _regularCount++;
      if (type == 'student') _studentCount++;
      if (type == 'senior') _seniorCount++;

      // 2. Instantiate a fresh, independent PassengerDetail model explicitly initialized with the requested type
      final newPassenger = PassengerDetail(
        index: _passengers.length + 1,
        category: type,
        initialGivenNames: '',
        initialLastName: '',
        initialIdNumber: '',
        isExpanded: true,
      );

      // 3. Mutate passenger list cleanly with the newly created model
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

    // Ensure there is at least one passenger of this specific category to remove
    final targetIndex = _passengers.lastIndexWhere((p) => p.category == type);
    if (targetIndex == -1) return;

    setState(() {
      // 1. Decrement specific category count
      if (type == 'regular' && _regularCount > 0) _regularCount--;
      if (type == 'student' && _studentCount > 0) _studentCount--;
      if (type == 'senior' && _seniorCount > 0) _seniorCount--;

      // 2. Remove the last passenger belonging to this specific type
      final removed = _passengers.removeAt(targetIndex);
      _unassignPassengerSeat(removed.index);
      removed.dispose();

      // 3. Re-index remaining passengers (1..N) and update seat assignments
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please complete details for Passenger ${p.index} (${p.categoryLabel}).',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }
    } else if (step == 2) {
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

    try {
      final booking = await _dataService.createBooking(
        scheduleId: widget.schedule.id,
        passengerName: primaryContactName,
        seatCount: _totalSeats,
        amountCollected: _totalPrice,
        notes: fullNotes,
        seatNumbers: chosenSeatNumbers,
        seatBreakdown: seatBreakdown,
        passengerId: PassengerSession.passengerId > 0 ? PassengerSession.passengerId : null,
        contactNumber: primaryContactPhone,
        email: primaryEmail,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppPalette.mintGreen, size: 28),
              SizedBox(width: 8),
              Text('Booking Confirmed!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reference #${booking.referenceNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppPalette.mintGreen,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Trip: ${widget.schedule.from} → ${widget.schedule.to}\n'
                'Seats: ${_passengers.map((p) => 'Seat #${p.assignedSeat}').join(', ')}\n'
                'Total Paid: ₱${_totalPrice.toStringAsFixed(2)}\n'
                'Payment: ${_paymentMethods.firstWhere((m) => m.id == _selectedPaymentId, orElse: () => _paymentMethods.first).name}',
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  PassengerHomeScreen.routeName,
                  (route) => false,
                  arguments: {'tabIndex': 1},
                );
              },
              child: const Text('VIEW MY BOOKINGS'),
            ),
          ],
        ),
      );
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
          setState(() => _currentStep = stepIndex);
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
        return _buildStep1PassengerDetails();
      case 1:
        return _buildStep2SeatSelection();
      case 2:
      default:
        return _buildStep3ReviewAndPayment();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1: Seat Counts & Dynamic Passenger Forms (Sample-2.png)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep1PassengerDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trip Route & Vessel Summary Card
        _buildTripSummaryCard(),
        const SizedBox(height: 18),

        // Seat Category Counter Selectors
        Text(
          'Select Seats & Passenger Types',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppPalette.darkText,
              ),
        ),
        const SizedBox(height: 10),

        _buildCounterRow(
          label: 'Regular',
          unitPrice: _fare.regular,
          count: _regularCount,
          onDecrement: () => _decrementCategory('regular'),
          onIncrement: () => _incrementCategory('regular'),
        ),
        const SizedBox(height: 8),

        _buildCounterRow(
          label: 'Student',
          badgeText: 'Discounted',
          unitPrice: _fare.student,
          count: _studentCount,
          onDecrement: () => _decrementCategory('student'),
          onIncrement: () => _incrementCategory('student'),
        ),
        const SizedBox(height: 8),

        _buildCounterRow(
          label: 'Senior Citizen / PWD',
          badgeText: '20% Off',
          unitPrice: _fare.senior,
          count: _seniorCount,
          onDecrement: () => _decrementCategory('senior'),
          onIncrement: () => _incrementCategory('senior'),
        ),
        const SizedBox(height: 22),

        // Dynamic Passenger Detail Cards
        Text(
          'Passenger Details (${_passengers.length} Total)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppPalette.darkText,
              ),
        ),
        const SizedBox(height: 10),

        ..._passengers.map((p) => _buildPassengerAccordionCard(p)),

        const SizedBox(height: 14),

        // Sticky Bottom Price & Action
        _buildStep1BottomBar(),
      ],
    );
  }

  Widget _buildPassengerAccordionCard(PassengerDetail passenger) {
    final bool isCompleted = passenger.isComplete;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? AppPalette.mintGreen.withValues(alpha: 0.5)
              : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Accordion Header
          InkWell(
            onTap: () {
              setState(() {
                passenger.isExpanded = !passenger.isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Passenger ${passenger.index}: ${passenger.categoryLabel}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppPalette.darkText,
                          ),
                        ),
                        if (passenger.fullName != 'Passenger ${passenger.index}') ...[
                          const SizedBox(height: 2),
                          Text(
                            passenger.fullName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppPalette.mintGreen.withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isCompleted ? 'Completed' : 'Not completed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? AppPalette.mintGreen : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Icon(
                    passenger.isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),

          // Accordion Body Form
          if (passenger.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Given Names
                  TextField(
                    controller: passenger.givenNamesController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Given names (including suffix) *',
                      hintText: 'e.g. Juan Jr.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Last Name
                  TextField(
                    controller: passenger.lastNameController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Last name (surname) *',
                      hintText: 'e.g. Dela Cruz',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  // Discount / ID Details if Student or Senior
                  if (passenger.category != 'regular') ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppPalette.mintGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppPalette.mintGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passenger.category == 'student'
                                ? 'Student Discount ID Verification *'
                                : 'Senior Citizen / PWD ID Verification *',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.mintGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: passenger.idNumberController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'ID / Card Number *',
                              hintText: 'e.g. 2024-STU-1029 / OSCA-1954',
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          passenger.isExpanded = false;
                          final nextIndex = passenger.index;
                          if (nextIndex < _passengers.length) {
                            _passengers[nextIndex].isExpanded = true;
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: AppPalette.darkText,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                      child: const Text('Save & continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep1BottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.mintGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL PRICE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '$_totalSeats Seat${_totalSeats == 1 ? '' : 's'} Selected',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.darkText,
                    ),
                  ),
                ],
              ),
              Text(
                '₱${_totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.mintGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _goToStep(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.mintGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'SELECT SEATS →',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2: Interactive Vessel Seat Map Selection (Sample-3.png)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep2SeatSelection() {
    final activePassenger = _passengers.isNotEmpty
        ? _passengers[_activePassengerIndex]
        : null;

    final int assignedCount = _passengers.where((p) => p.assignedSeat != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vessel Cabin Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.schedule.boatName.isNotEmpty
                        ? widget.schedule.boatName
                        : 'Vessel Cabin Seat Map',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppPalette.darkText,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Economy Class',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.schedule.from} → ${widget.schedule.to} • ${widget.schedule.time}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),

        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _passengers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final p = _passengers[i];
              final bool isCurrent = i == _activePassengerIndex;
              final bool hasSeat = p.assignedSeat != null;

              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'P${p.index}: ${p.fullName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasSeat
                            ? AppPalette.mintGreen
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasSeat ? p.assignedSeat! : '--',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                selected: isCurrent,
                selectedColor: AppPalette.mintGreen.withValues(alpha: 0.2),
                onSelected: (_) {
                  setState(() {
                    _activePassengerIndex = i;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Seat Status Legend (Available, Selected, Unavailable)
        _buildSeatLegend(),
        const SizedBox(height: 14),

        // Vessel Cabin Visual Outline & Grid
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(60),
                bottom: Radius.circular(20),
              ),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.navigation_rounded, size: 14, color: AppPalette.mintGreen),
                      SizedBox(width: 4),
                      Text(
                        'FRONT / BOW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Exit Indicators
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('« EXIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('EXIT »', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
                const Divider(height: 20),

                // Seat Rows
                ...List.generate(_totalRows, (rIndex) => _buildSeatRow(rIndex + 1)),

                const SizedBox(height: 10),
                const Text(
                  'AFT / STERN',
                  style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Bottom Controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assigned: $assignedCount / $_totalSeats Seats',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (activePassenger != null)
                    Text(
                      'Editing: P${activePassenger.index}',
                      style: const TextStyle(
                        color: AppPalette.mintGreen,
                        fontWeight: FontWeight.bold,
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
                      onPressed: () => setState(() => _currentStep = 0),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('← Details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: assignedCount == _totalSeats ? () => _goToStep(2) : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.mintGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'REVIEW & PAY →',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildSeatLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Available', Colors.white, Colors.blue.shade400, const Text('')),
        _buildLegendItem('Selected', AppPalette.mintGreen, AppPalette.mintGreen, const Icon(Icons.check, size: 12, color: Colors.white)),
        _buildLegendItem('Booked', Colors.grey.shade200, Colors.grey.shade300, const Icon(Icons.close, size: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color fill, Color border, Widget child) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Center(child: child),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSeatRow(int rowNumber) {
    final rowSeats = _seats.where((s) => s.row == rowNumber).toList();
    final leftSide = rowSeats.where((s) => s.column == 'A' || s.column == 'B').toList();
    final rightSide = rowSeats.where((s) => s.column == 'C' || s.column == 'D' || s.column == 'E').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left bank [A] [B]
          ...leftSide.map((seat) => _buildSeatBox(seat)),

          // Aisle with row number
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$rowNumber',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
          ),

          // Right bank [C] [D] [E]
          ...rightSide.map((seat) => _buildSeatBox(seat)),
        ],
      ),
    );
  }

  Widget _buildSeatBox(VesselSeat seat) {
    Color bg = Colors.white;
    Color border = Colors.blue.shade200;
    Widget child = Text(
      seat.column,
      style: TextStyle(
        fontSize: 12,
        color: Colors.blue.shade600,
        fontWeight: FontWeight.bold,
      ),
    );

    if (seat.isBooked) {
      bg = Colors.grey.shade200;
      border = Colors.grey.shade300;
      child = const Icon(Icons.close, size: 14, color: Colors.grey);
    } else if (seat.isSelected) {
      bg = AppPalette.mintGreen;
      border = AppPalette.mintGreen;
      child = Text(
        'P${seat.assignedPassengerIndex}',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () => _onSeatTapped(seat),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Center(child: child),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: Booking Summary, Hold Timer & Payment (Sample-4.png)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep3ReviewAndPayment() {
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
                        text: _formattedHoldTime,
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

        // Select Payment Method (Sample-4.png)
        Text(
          'Select a Payment Method',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppPalette.darkText,
              ),
        ),
        const SizedBox(height: 10),

        ..._paymentMethods.map((pm) => _buildPaymentTile(pm)),

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
                onPressed: () => setState(() => _currentStep = 1),
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
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.mintGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'CONFIRM & PAY (₱${_totalPrice.toStringAsFixed(2)})',
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
    final bool isSelected = _selectedPaymentId == option.id;

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
        onTap: () => setState(() => _selectedPaymentId = option.id),
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
                '${widget.schedule.from} → ${widget.schedule.to}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.mintGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.schedule.boatName,
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
            'Date: ${widget.schedule.date} • Departure: ${widget.schedule.time}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          // Assigned Passengers & Seats
          const Text(
            'Assigned Passengers & Seats:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          ..._passengers.map(
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

          if (_regularCount > 0)
            _buildPriceDetailRow(
              '$_regularCount × Adult Regular (₱${_fare.regular.toStringAsFixed(2)})',
              '₱${(_regularCount * _fare.regular).toStringAsFixed(2)}',
            ),

          if (_studentCount > 0)
            _buildPriceDetailRow(
              '$_studentCount × Student (₱${_fare.student.toStringAsFixed(2)})',
              '₱${(_studentCount * _fare.student).toStringAsFixed(2)}',
            ),

          if (_seniorCount > 0)
            _buildPriceDetailRow(
              '$_seniorCount × Senior/PWD (₱${_fare.senior.toStringAsFixed(2)})',
              '₱${(_seniorCount * _fare.senior).toStringAsFixed(2)}',
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
                '₱${_totalPrice.toStringAsFixed(2)}',
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

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildTripSummaryCard() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.schedule.from} → ${widget.schedule.to}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.darkText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPalette.mintGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.schedule.availableSeats} seats left',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.mintGreen,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: AppPalette.mintGreen),
              const SizedBox(width: 8),
              Text(
                'Travel Date: ${widget.schedule.date.isNotEmpty ? widget.schedule.date : 'Selected Date'}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: AppPalette.mintGreen),
              const SizedBox(width: 8),
              Text(
                'Departure Time: ${widget.schedule.time}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.directions_boat_outlined, size: 16, color: AppPalette.mintGreen),
              const SizedBox(width: 8),
              Text(
                'Vessel / Boat: ${widget.schedule.boatName}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterRow({
    required String label,
    required double unitPrice,
    required int count,
    String? badgeText,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0
              ? AppPalette.mintGreen.withValues(alpha: 0.5)
              : Colors.grey.shade300,
          width: count > 0 ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppPalette.darkText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppPalette.mintGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.mintGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${unitPrice.toStringAsFixed(2)} / passenger',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: count > 0 ? onDecrement : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppPalette.mintGreen,
                disabledColor: Colors.grey.shade300,
                iconSize: 24,
              ),
              SizedBox(
                width: 20,
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline),
                color: AppPalette.mintGreen,
                iconSize: 24,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
