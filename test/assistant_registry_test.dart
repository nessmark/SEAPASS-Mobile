// Keeps the assistant's page registry, the screens and the Android host in step.
//
// The model may only point at targets the app sends in its page context, and
// the host guide can only spotlight anchors that are really rendered. These
// checks read the sources so a renamed or dropped anchor fails here first.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/widgets/assistant/assistant_pages.dart';

/// Screen sources that render each assistant page.
const pageSources = <String, List<String>>{
  'trips': ['lib/screens/trip_schedules_screen.dart'],
  'bookings': ['lib/screens/my_bookings_screen.dart'],
  'advisories': ['lib/screens/advisories_screen.dart'],
  'profile': ['lib/screens/my_account_screen.dart'],
  'checkout': [
    'lib/screens/checkout/booking_checkout_screen.dart',
    'lib/screens/checkout/steps/checkout_step_details.dart',
    'lib/screens/checkout/steps/checkout_step_seat_map.dart',
    'lib/screens/checkout/steps/checkout_step_payment.dart',
  ],
  'ticket': ['lib/screens/view_ticket_screen.dart'],
};

/// Screens with their own top bar that host the launcher, and the page they report.
const launcherScreens = <String, String>{
  'lib/screens/passenger_home_screen.dart': 'shell',
  'lib/screens/checkout/booking_checkout_screen.dart': 'checkout',
  'lib/screens/view_ticket_screen.dart': 'ticket',
};

String read(String path) => File(path).readAsStringSync();

void main() {
  test('every registered page has screens and every target has a rendered anchor', () {
    expect(pageSources.keys.toSet(), assistantPages.keys.toSet());
    for (final page in assistantPages.values) {
      final source = pageSources[page.path]!.map(read).join('\n');
      for (final target in page.targets) {
        expect(source, contains(".guide('${target.id}')"), reason: '${page.path}/${target.id}');
      }
    }
  });

  test('target ids are unique across pages, so one anchor never answers for two pages', () {
    final ids = assistantPages.values.expand((p) => p.targets.map((t) => t.id)).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('guide copy is plain: no em dashes and no developer notes', () {
    for (final target in assistantPages.values.expand((p) => p.targets)) {
      for (final text in [target.title, target.body, target.label]) {
        expect(text.contains('—'), isFalse, reason: text);
        expect(RegExp(r'\b(TODO|debug|endpoint|api)\b', caseSensitive: false).hasMatch(text), isFalse, reason: text);
      }
    }
  });

  test('the shell tabs and the navigation map agree', () {
    expect(assistantTabIndex.keys.toSet(), {'trips', 'bookings', 'advisories', 'profile'});
    for (final page in assistantTabIndex.keys) {
      expect(assistantPages.containsKey(page), isTrue, reason: page);
    }
  });

  test('the launcher is on every main passenger screen', () {
    for (final entry in launcherScreens.entries) {
      final source = read(entry.key);
      expect(source, contains('SeaPassAssistantButton('), reason: entry.key);
      if (entry.value != 'shell') expect(source, contains("pagePath: '${entry.value}'"), reason: entry.key);
    }
    // The shell reports the open tab, one of the four tab pages.
    final shell = read('lib/screens/passenger_home_screen.dart');
    for (final page in ['trips', 'bookings', 'advisories', 'profile']) {
      expect(shell, contains("'$page'"), reason: page);
    }
  });

  test('the Android host can record voice and reach the server', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    for (final permission in ['INTERNET', 'RECORD_AUDIO', 'MODIFY_AUDIO_SETTINGS']) {
      expect(manifest, contains('android.permission.$permission'), reason: permission);
    }
  });

  test('the web host lets the embedded page use the microphone', () {
    final web = read('lib/widgets/assistant/assistant_surface_web.dart');
    expect(web, contains("allow = 'microphone"));
    // Only messages from the assistant frame and origin are trusted.
    expect(web, contains('event.origin != widget.uri.origin'));
  });

  test('the native host grants media only through the origin rule and keeps file picks to allowed types', () {
    final native = read('lib/widgets/assistant/assistant_surface_native.dart');
    expect(native, contains('shouldGrantAssistantMedia('));
    expect(native, contains('isAssistantNavigationAllowed('));
    expect(native, contains('assistantPickerExtensions('));
  });
}
