import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/widgets/assistant/page_guide.dart';

void main() {
  testWidgets(
      'a guide scrolls to its actual control and can close at phone width',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  appBar: AppBar(actions: [
                    TextButton(
                        onPressed: () => showSeaPassPageGuide(
                            context, 'trips', {'target': 'date_rail'}),
                        child: const Text('Guide'))
                  ]),
                  body: SingleChildScrollView(
                      child: Column(children: [
                    const SizedBox(height: 1100),
                    const SizedBox(
                            height: 70,
                            child: Text('Actual travel date control'))
                        .guide('date_rail'),
                    const SizedBox(height: 300),
                  ])),
                ))));
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a travel date'), findsOneWidget);
    final anchor = SeaPassGuideAnchor.anchors['date_rail']!.currentContext!
        .findRenderObject()! as RenderBox;
    expect(anchor.localToGlobal(Offset.zero).dy, greaterThanOrEqualTo(0));
    expect(anchor.localToGlobal(Offset.zero).dy + anchor.size.height,
        lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a travel date'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(SeaPassGuideAnchor.anchors.containsKey('date_rail'), isFalse);
  });

  testWidgets('missing targets do not pretend to highlight a control',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showSeaPassPageGuide(
                          context, 'trips', {'target': 'missing'}),
                      child: const Text('Guide')),
                ))));
    await tester.tap(find.text('Guide'));
    await tester.pump();
    expect(find.text('That control is not visible on this screen yet.'),
        findsOneWidget);
  });
}
