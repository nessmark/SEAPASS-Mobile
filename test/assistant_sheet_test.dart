import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/models/booking.dart';
import 'package:seapass_passenger_app/screens/view_ticket_screen.dart';
import 'package:seapass_passenger_app/services/assistant_service.dart';
import 'package:seapass_passenger_app/theme/app_theme.dart';
import 'package:seapass_passenger_app/widgets/assistant/assistant_navigation.dart';
import 'package:seapass_passenger_app/widgets/assistant/page_guide.dart';
import 'package:seapass_passenger_app/widgets/assistant_button.dart';

/// Stands in for the WebView or iframe. Tests drive it through [emit].
class FakeSurface {
  ValueChanged<Map<String, dynamic>>? emit;
  Map<String, dynamic>? config;
  int built = 0;

  Widget build(BuildContext context, Uri uri, Map<String, dynamic> config, ValueChanged<Map<String, dynamic>> onEvent) {
    built++;
    this.config = config;
    emit = onEvent;
    return const ColoredBox(color: Colors.transparent, child: Center(child: Text('assistant page')));
  }

  void ready() => emit!({'source': 'seapass-assistant', 'type': 'ready'});
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

int loads = 0;

Future<Map<String, dynamic>> okConfig({
  required String label,
  required String path,
  required String theme,
  String? details,
  Iterable<String>? mountedTargets,
}) async {
  loads++;
  return {'token': 't', 'identity': 'passenger-1', 'theme': theme, 'context': {'path': path, 'label': label, 'details': details}};
}

Widget sheetHost(AssistantSheet sheet) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: sheet));

AssistantSheet sheet({
  required Future<Map<String, dynamic>> Function() load,
  FakeSurface? surface,
  VoidCallback? onClose,
  VoidCallback? onSignIn,
  VoidCallback? onShowGuide,
  ValueChanged<Map<String, dynamic>>? onEvent,
  Duration readyTimeout = const Duration(seconds: 30),
  Duration loadTimeout = const Duration(seconds: 25),
  bool canShowGuide = true,
  Future<bool> Function()? openSettings,
}) {
  final fake = surface ?? FakeSurface();
  return AssistantSheet(
    load: load,
    uri: Uri.parse('https://seapass.example.ph/assistant/embed'),
    surfaceBuilder: fake.build,
    onEvent: onEvent ?? (_) {},
    onClose: onClose ?? () {},
    onSignIn: onSignIn ?? () {},
    onShowGuide: onShowGuide ?? () {},
    readyTimeout: readyTimeout,
    loadTimeout: loadTimeout,
    canShowGuide: canShowGuide,
    openSettings: openSettings ?? () async => false,
  );
}

void main() {
  group('AssistantSheet states', () {
    testWidgets('loading, then the page once it reports ready', (tester) async {
      phone(tester);
      final surface = FakeSurface();
      final completer = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(sheetHost(sheet(load: () => completer.future, surface: surface)));
      expect(find.text('Opening the assistant…'), findsOneWidget);
      completer.complete({'token': 't', 'identity': 'p'});
      await tester.pump();
      expect(surface.built, 1);
      expect(find.text('Opening the assistant…'), findsOneWidget, reason: 'covered until the page is ready');
      surface.ready();
      await tester.pump();
      expect(find.text('Opening the assistant…'), findsNothing);
      expect(find.text('assistant page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    final cases = <AssistantFailureKind, (String, String?)>{
      AssistantFailureKind.offline: ('You are offline', 'Try again'),
      AssistantFailureKind.unreachable: ('Cannot reach SeaPass', 'Try again'),
      AssistantFailureKind.signedOut: ('Sign in to use the assistant', 'Sign in'),
      AssistantFailureKind.notConfigured: ('Assistant unavailable', null),
      AssistantFailureKind.unavailable: ('Assistant unavailable', 'Try again'),
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key.name} has one clear state at 360x800', (tester) async {
        phone(tester);
        await tester.pumpWidget(sheetHost(sheet(load: () async => throw AssistantUnavailable(entry.key))));
        await tester.pump();
        final (title, action) = entry.value;
        expect(find.text(title), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        if (action != null) expect(find.widgetWithText(FilledButton, action), findsOneWidget);
        if (action == null) expect(find.byType(FilledButton), findsNothing);
        expect(find.text('Close'), findsOneWidget);
        final guide = find.text('Show me this page');
        expect(guide, entry.key == AssistantFailureKind.signedOut ? findsNothing : findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Try again loads again and recovers', (tester) async {
      phone(tester);
      var attempts = 0;
      final surface = FakeSurface();
      await tester.pumpWidget(sheetHost(sheet(
        surface: surface,
        load: () async {
          attempts++;
          if (attempts == 1) throw const AssistantUnavailable(AssistantFailureKind.unreachable);
          return {'token': 't', 'identity': 'p'};
        },
      )));
      await tester.pump();
      expect(find.text('Cannot reach SeaPass'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(attempts, 2);
      surface.ready();
      await tester.pump();
      expect(find.text('assistant page'), findsOneWidget);
      expect(find.text('Cannot reach SeaPass'), findsNothing);
    });

    testWidgets('a server that never answers ends in a retry, not a spinner', (tester) async {
      phone(tester);
      await tester.pumpWidget(sheetHost(sheet(
          load: () => Completer<Map<String, dynamic>>().future, loadTimeout: const Duration(seconds: 5))));
      await tester.pump(const Duration(seconds: 6));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cannot reach SeaPass'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a page that never reports ready times out', (tester) async {
      phone(tester);
      await tester.pumpWidget(sheetHost(sheet(load: () async => {'token': 't'}, readyTimeout: const Duration(seconds: 3))));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Taking too long'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a page load error and an unsupported platform show their own states', (tester) async {
      phone(tester);
      final surface = FakeSurface();
      await tester.pumpWidget(sheetHost(sheet(load: () async => {'token': 't'}, surface: surface)));
      await tester.pump();
      surface.emit!({'type': 'surface_error', 'reason': 'load_failed'});
      await tester.pump();
      expect(find.text('The assistant page could not load. Check your connection and try again.'), findsOneWidget);

      final offline = FakeSurface();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(sheetHost(sheet(load: () async => {'token': 't'}, surface: offline)));
      await tester.pump();
      offline.emit!({'type': 'surface_error', 'reason': 'offline'});
      await tester.pump();
      expect(find.text('You are offline'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      final other = FakeSurface();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(sheetHost(sheet(load: () async => {'token': 't'}, surface: other)));
      await tester.pump();
      other.emit!({'type': 'surface_error', 'reason': 'unsupported'});
      await tester.pump();
      expect(find.text('Assistant unavailable'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a blocked microphone points to Settings and can be dismissed', (tester) async {
      phone(tester);
      final surface = FakeSurface();
      var opened = 0;
      await tester.pumpWidget(sheetHost(sheet(
          load: () async => {'token': 't'},
          surface: surface,
          openSettings: () async {
            opened++;
            return true;
          })));
      await tester.pump();
      surface.ready();
      surface.emit!({'type': 'mic_blocked'});
      await tester.pump();
      expect(find.text('Microphone is off for SeaPass. You can still type.'), findsOneWidget);
      final surfaceRect = tester.getRect(find.text('assistant page'));
      final bannerRect = tester.getRect(find.text('Microphone is off for SeaPass. You can still type.'));
      expect(surfaceRect.bottom, lessThanOrEqualTo(bannerRect.top));
      await tester.tap(find.text('Settings'));
      expect(opened, 1);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.text('Microphone is off for SeaPass. You can still type.'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('page events other than ready and errors go to the host', (tester) async {
      final surface = FakeSurface();
      final events = <Map<String, dynamic>>[];
      await tester.pumpWidget(sheetHost(sheet(load: () async => {'token': 't'}, surface: surface, onEvent: events.add)));
      await tester.pump();
      surface.ready();
      surface.emit!({'source': 'seapass-assistant', 'type': 'navigate', 'page': 'bookings'});
      await tester.pump();
      expect(events.map((e) => e['type']), ['navigate']);
    });
  });

  group('SeaPassAssistantButton', () {
    late FakeSurface surface;

    Widget app({
      ValueChanged<Map<String, dynamic>>? onNavigation,
      Future<bool> Function(BuildContext)? confirmLeave,
      Future<bool> Function(Map<String, dynamic>)? onGuideAction,
      bool withPopScope = false,
    }) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (context) {
          final scaffold = Scaffold(
            appBar: AppBar(title: const Text('My Bookings'), actions: [
              SeaPassAssistantButton(
                pageLabel: 'My Bookings',
                pagePath: 'bookings',
                onNavigation: onNavigation,
                confirmLeave: confirmLeave,
                onGuideAction: onGuideAction,
                bootstrapper: okConfig,
                surfaceBuilder: surface.build,
              ),
            ]),
            body: ListView(children: [
              const SizedBox(height: 60, child: Text('Tabs')).guide('tabs'),
              const SizedBox(height: 200, child: Text('Booking list')).guide('booking_card'),
            ]),
          );
          return withPopScope ? PopScope(canPop: false, child: scaffold) : scaffold;
        }),
      );
    }

    setUp(() {
      surface = FakeSurface();
      loads = 0;
    });

    // The loading spinner never settles, so wait out the sheet animation by time.
    Future<void> openSheet(WidgetTester tester, {bool tap = true}) async {
      if (tap) await tester.tap(find.text('Ask SeaPass'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      surface.ready();
      await tester.pumpAndSettle();
    }

    testWidgets('opens one sheet with the screen context and its mounted targets', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await openSheet(tester);
      expect(find.text('assistant page'), findsOneWidget);
      expect(SeaPassAssistantButton.isOpen, isTrue);
      expect(surface.config!['context'], containsPair('path', 'bookings'));
      expect(surface.config!['theme'], 'light');
      final button = tester.widget<SeaPassAssistantButton>(find.byType(SeaPassAssistantButton));
      unawaited(button.open(tester.element(find.byType(SeaPassAssistantButton))));
      await tester.pumpAndSettle();
      expect(loads, 1, reason: 'a second open never stacks another sheet');
      expect(find.byType(AssistantSheet), findsOneWidget);
    });

    testWidgets('Android back closes the sheet and keeps the screen', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(withPopScope: true));
      await openSheet(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('assistant page'), findsNothing);
      expect(find.text('My Bookings'), findsOneWidget);
      expect(SeaPassAssistantButton.isOpen, isFalse);
    });

    testWidgets('the page close message closes only the sheet', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await openSheet(tester);
      surface.emit!({'source': 'seapass-assistant', 'type': 'close'});
      await tester.pumpAndSettle();
      expect(find.text('assistant page'), findsNothing);
      expect(find.text('Booking list'), findsOneWidget);
      // A late duplicate must not pop the screen underneath.
      surface.emit!({'source': 'seapass-assistant', 'type': 'close'});
      await tester.pumpAndSettle();
      expect(find.text('Booking list'), findsOneWidget);
    });

    testWidgets('navigate sends only sanitized prefill and closes the sheet', (tester) async {
      phone(tester);
      final received = <Map<String, dynamic>>[];
      await tester.pumpWidget(app(onNavigation: received.add));
      await openSheet(tester);
      surface.emit!({
        'source': 'seapass-assistant',
        'type': 'navigate',
        'page': 'trips',
        'args': {'trip_id': 4, 'seats': 2, 'pay': true, 'confirm': 'yes'},
      });
      await tester.pumpAndSettle();
      expect(find.text('assistant page'), findsNothing);
      expect(received, hasLength(1));
      expect(received.single['page'], 'trips');
      expect(received.single['args'], {'trip_id': 4, 'seats': 2});
    });

    testWidgets('unknown pages are ignored and the sheet stays open', (tester) async {
      phone(tester);
      final received = <Map<String, dynamic>>[];
      await tester.pumpWidget(app(onNavigation: received.add));
      await openSheet(tester);
      surface.emit!({'source': 'seapass-assistant', 'type': 'navigate', 'page': 'dashboard'});
      await tester.pumpAndSettle();
      expect(find.text('assistant page'), findsOneWidget);
      expect(received, isEmpty);
    });

    testWidgets('a declined leave keeps the passenger where they are', (tester) async {
      phone(tester);
      final received = <Map<String, dynamic>>[];
      await tester.pumpWidget(app(
        onNavigation: received.add,
        confirmLeave: (context) =>
            confirmAssistantLeave(context, title: 'Leave checkout?', message: 'Nothing has been paid.'),
      ));
      await openSheet(tester);
      surface.emit!({'source': 'seapass-assistant', 'type': 'navigate', 'page': 'bookings'});
      await tester.pumpAndSettle();
      expect(find.text('Leave checkout?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(received, isEmpty);
      expect(find.text('assistant page'), findsOneWidget);

      surface.emit!({'source': 'seapass-assistant', 'type': 'navigate', 'page': 'bookings'});
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(received.single['page'], 'bookings');
      expect(find.text('assistant page'), findsNothing);
    });

    testWidgets('a guide from the assistant closes the sheet, points, then offers the chat again', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await openSheet(tester);
      surface.emit!({
        'source': 'seapass-assistant',
        'type': 'guide',
        'action': {
          'type': 'highlight_element',
          'args': {'target': 'booking_card', 'message': 'Tap a booking to see its QR.'}
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('assistant page'), findsNothing);
      expect(find.text('Open your boarding pass'), findsOneWidget);
      expect(find.text('Tap a booking to see its QR.'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Back to chat'), findsOneWidget);
      await tester.tap(find.text('Back to chat'));
      await openSheet(tester, tap: false);
      expect(loads, 2);
      expect(find.text('assistant page'), findsOneWidget);
    });

    testWidgets('a tour walks every mounted target on the screen', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await openSheet(tester);
      surface.emit!({'source': 'seapass-assistant', 'type': 'guide'});
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 2'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 2'), findsOneWidget);
      // Back closes the guide card, not the screen.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 2'), findsNothing);
      expect(find.text('Booking list'), findsOneWidget);
    });

    testWidgets('hides Show me this page on failure when no guide anchors are mounted', (tester) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('My Bookings'), actions: [
            SeaPassAssistantButton(
              pageLabel: 'My Bookings',
              pagePath: 'bookings',
              bootstrapper: ({required label, required path, required theme, details, mountedTargets}) async =>
                  throw const AssistantUnavailable(AssistantFailureKind.offline),
              surfaceBuilder: surface.build,
            ),
          ]),
          body: const Center(child: Text('Error loading bookings')),
        ),
      ));
      await tester.tap(find.text('Ask SeaPass'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('You are offline'), findsOneWidget);
      expect(find.text('Show me this page'), findsNothing);
    });

    testWidgets('soft keyboard inset lifts the sheet without restarting bootstrap', (tester) async {
      phone(tester);
      await tester.pumpWidget(app());
      await openSheet(tester);
      expect(loads, 1);
      expect(surface.built, 1);
      final beforeBottom = tester.getRect(find.byType(AssistantSheet)).bottom;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      final afterBottom = tester.getRect(find.byType(AssistantSheet)).bottom;
      expect(afterBottom, lessThan(beforeBottom));
      expect(loads, 1);
      expect(surface.built, 1);
    });
  });

  group('launcher placement at 360x800', () {
    const booking = Booking(
      id: '12',
      referenceNumber: 'SP-2026-0921-0042',
      passengerName: 'Marilou Bautista',
      route: 'Surigao City → San Jose',
      date: 'Sep 21, 2026',
      time: '08:00 AM',
      boatName: 'MB Dinagat Star',
      seatCount: 2,
      seatNumbers: ['4D', '4E'],
      totalPrice: 1908.0,
      status: 'confirmed',
      showViewTicket: true,
    );

    testWidgets('the boarding pass has the launcher in its top bar, clear of Save', (tester) async {
      phone(tester);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const ViewTicketScreen(booking: booking)));
      await tester.pump();
      final launcher = find.byKey(const ValueKey('assistant-launcher'));
      expect(launcher, findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: launcher), findsOneWidget);
      final launcherRect = tester.getRect(launcher);
      expect(launcherRect.right, lessThanOrEqualTo(360));
      expect(launcherRect.width, greaterThanOrEqualTo(48));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('ticket-save')), 200);
      expect(launcherRect.overlaps(tester.getRect(find.byKey(const ValueKey('ticket-save')))), isFalse);
      for (final id in ['trip_summary', 'boarding_qr', 'save_tickets']) {
        expect(SeaPassGuideAnchor.anchors[id]?.currentContext?.mounted, isTrue, reason: id);
      }
      expect(tester.takeException(), isNull);
    });
  });

  tearDown(() => AssistantNavigationBus.pending.value = null);
}
