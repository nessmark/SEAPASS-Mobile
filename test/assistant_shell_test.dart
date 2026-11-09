import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:seapass_passenger_app/config/api_config.dart';
import 'package:seapass_passenger_app/providers/advisory_provider.dart';
import 'package:seapass_passenger_app/screens/passenger_home_screen.dart';
import 'package:seapass_passenger_app/theme/app_theme.dart';
import 'package:seapass_passenger_app/widgets/assistant/assistant_navigation.dart';
import 'package:seapass_passenger_app/widgets/assistant/page_guide.dart';
import 'package:seapass_passenger_app/widgets/assistant/assistant_pages.dart';
import 'package:seapass_passenger_app/widgets/assistant_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiConfig.customBaseUrl = 'http://127.0.0.1:9';
    AssistantNavigationBus.pending.value = null;
  });

  tearDown(() {
    ApiConfig.customBaseUrl = '';
    AssistantNavigationBus.pending.value = null;
  });

  // The square test font is about twice as wide as a phone font, which makes
  // the tab pill and the date rail report overflow at 360 here. Those are not
  // part of this check, so overflow reports are set aside and the launcher is
  // checked by its real position instead. Every other error still fails.
  void ignoreTestFontOverflow() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is FlutterError && details.exceptionAsString().contains('overflowed by')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  Future<void> pumpShell(WidgetTester tester, {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ignoreTestFontOverflow();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => AdvisoryProvider(),
      child: MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: const PassengerHomeScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  // The tabs poll the server, so drop the tree before the test ends.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('every passenger tab keeps the launcher in the top bar, clear of the tab bar', (tester) async {
    await pumpShell(tester);
    final launcher = find.byKey(const ValueKey('assistant-launcher'));
    const tabs = <String, (String, String)>{
      'Trips': ('trips', 'SeaPass'),
      'Bookings': ('bookings', 'My Bookings'),
      'Advisories': ('advisories', 'Advisories'),
      'Account': ('profile', 'My Account'),
    };
    for (final entry in tabs.entries) {
      final tab = entry.key;
      final (expectedPath, expectedTitle) = entry.value;
      final tabRect = tester.getRect(find.text(tab).last);
      expect(tabRect.left, greaterThanOrEqualTo(0), reason: tab);
      expect(tabRect.right, lessThanOrEqualTo(360), reason: tab);
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 400));
      expect(launcher, findsOneWidget, reason: tab);
      expect(find.descendant(of: find.byType(AppBar), matching: launcher), findsOneWidget, reason: tab);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text(expectedTitle)), findsOneWidget, reason: tab);
      final button = tester.widget<SeaPassAssistantButton>(find.byType(SeaPassAssistantButton));
      expect(button.pagePath, expectedPath, reason: tab);
      final rect = tester.getRect(launcher);
      expect(rect.left, greaterThanOrEqualTo(0), reason: tab);
      expect(rect.right, lessThanOrEqualTo(360), reason: tab);
      expect(rect.height, greaterThanOrEqualTo(48), reason: tab);
      expect(rect.overlaps(tester.getRect(find.text(tab).last)), isFalse, reason: tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
    await dispose(tester);
  });

  testWidgets('every tab renders the guide anchors its assistant page offers', (tester) async {
    await pumpShell(tester);
    for (final path in ['trips', 'bookings', 'advisories', 'profile']) {
      for (final target in assistantPages[path]!.targets) {
        expect(SeaPassGuideAnchor.anchors[target.id]?.currentContext?.mounted, isTrue, reason: '$path/${target.id}');
      }
    }
    await dispose(tester);
  });

  testWidgets('a request from a pushed screen switches the tab', (tester) async {
    await pumpShell(tester);
    AssistantNavigationBus.pending.value = AssistantNavigationRequest.fromEvent({'page': 'bookings'});
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('My Bookings'), findsWidgets);
    expect(AssistantNavigationBus.pending.value, isNull);

    AssistantNavigationBus.pending.value = AssistantNavigationRequest.fromEvent({'page': 'account'});
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('My Account'), findsWidgets);
    await dispose(tester);
  });

  testWidgets('start_booking prefill fills the trip search and opens nothing else', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Account').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.descendant(of: find.byType(AppBar), matching: find.text('My Account')), findsOneWidget);
    final day = DateTime.now().add(const Duration(days: 2));
    AssistantNavigationBus.pending.value = AssistantNavigationRequest.fromEvent({
      'page': 'trips',
      'args': {'date': _ymd(day), 'route': 'San Jose to Surigao', 'seats': 2, 'pay': true},
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('San Jose → Surigao'), findsOneWidget);
    // Still on the shell: no checkout or payment screen was pushed.
    expect(find.byType(PassengerHomeScreen), findsOneWidget);
    expect(find.text('Booking Checkout'), findsNothing);
    expect(find.text('Secure checkout'), findsNothing);
    await dispose(tester);
  });
}
