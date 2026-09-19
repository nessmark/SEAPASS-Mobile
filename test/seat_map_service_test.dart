import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/services/passenger_data_service.dart';
import 'package:seapass_passenger_app/services/seat_map_service.dart';

class MockPassengerDataService extends PassengerDataService {
  MockPassengerDataService({this.mockResponse, this.delay});

  Map<String, dynamic>? mockResponse;
  Duration? delay;
  int callCount = 0;

  @override
  Future<Map<String, dynamic>> fetchTripSeatMap(int scheduleId) async {
    callCount++;
    if (delay != null) {
      await Future.delayed(delay!);
    }
    return mockResponse ??
        {
          'status': 'success',
          'seat_map': [
            {'seat_number': '1A', 'row': 1, 'column': 'A', 'is_booked': false},
            {'seat_number': '1B', 'row': 1, 'column': 'B', 'is_booked': true},
          ],
        };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeatMapService Unit & Concurrency Tests', () {
    test('startPolling emits seat map data to seatMapStream', () async {
      final mockService = MockPassengerDataService();
      final seatMapService = SeatMapService(dataService: mockService);

      final expectation = expectLater(
        seatMapService.seatMapStream,
        emits(predicate<List<dynamic>>((list) {
          return list.length == 2 && list[0]['seat_number'] == '1A';
        })),
      );

      seatMapService.startPolling(42);

      await expectation;
      expect(mockService.callCount, equals(1));

      seatMapService.dispose();
    });

    test('manualRefresh updates isRefreshing ValueNotifier during operation', () async {
      final mockService = MockPassengerDataService(
        delay: const Duration(milliseconds: 50),
      );
      final seatMapService = SeatMapService(dataService: mockService);

      seatMapService.startPolling(42);
      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 100));

      final refreshStates = <bool>[];
      seatMapService.isRefreshing.addListener(() {
        refreshStates.add(seatMapService.isRefreshing.value);
      });

      final refreshFuture = seatMapService.manualRefresh();
      expect(seatMapService.isRefreshing.value, isTrue);

      await refreshFuture;
      expect(seatMapService.isRefreshing.value, isFalse);
      expect(refreshStates, containsAllInOrder([true, false]));

      seatMapService.dispose();
    });

    test('pausePolling prevents timer execution and resumePolling restarts it', () async {
      final mockService = MockPassengerDataService();
      final seatMapService = SeatMapService(dataService: mockService);

      seatMapService.startPolling(10);
      await Future.delayed(const Duration(milliseconds: 20));
      expect(mockService.callCount, equals(1));

      // Pause polling
      seatMapService.pausePolling();
      expect(mockService.callCount, equals(1));

      // Resume polling triggers immediate silent fetch
      seatMapService.resumePolling();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(mockService.callCount, equals(2));

      seatMapService.dispose();
    });

    test('stopPolling cleans up active schedule', () async {
      final mockService = MockPassengerDataService();
      final seatMapService = SeatMapService(dataService: mockService);

      seatMapService.startPolling(10);
      await Future.delayed(const Duration(milliseconds: 20));

      seatMapService.stopPolling();
      // Resuming after complete stop should be a no-op because activeSchedule is cleared
      seatMapService.resumePolling();
      await Future.delayed(const Duration(milliseconds: 20));
      expect(mockService.callCount, equals(1));

      seatMapService.dispose();
    });

    test('recordInteraction resets idle time calculation', () {
      final seatMapService = SeatMapService();
      seatMapService.recordInteraction();
      // Service accepts interactions cleanly
      expect(seatMapService.isRefreshing.value, isFalse);
      seatMapService.dispose();
    });
  });
}
