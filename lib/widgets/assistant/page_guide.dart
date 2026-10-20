import 'package:flutter/material.dart';

/// Registered rendered controls, scoped to the currently displayed app screen.
class SeaPassGuideAnchor extends StatefulWidget {
  final String id;
  final Widget child;
  const SeaPassGuideAnchor({super.key, required this.id, required this.child});
  static final Map<String, GlobalKey> anchors = {};
  @override
  State<SeaPassGuideAnchor> createState() => _SeaPassGuideAnchorState();
}

class _SeaPassGuideAnchorState extends State<SeaPassGuideAnchor> {
  final GlobalKey anchor = GlobalKey();
  @override
  Widget build(BuildContext context) {
    SeaPassGuideAnchor.anchors[widget.id] = anchor;
    return SizedBox(key: anchor, child: widget.child);
  }

  @override
  void dispose() {
    if (SeaPassGuideAnchor.anchors[widget.id] == anchor) {
      SeaPassGuideAnchor.anchors.remove(widget.id);
    }
    super.dispose();
  }
}

extension SeaPassGuidedWidget on Widget {
  Widget guide(String id) => SeaPassGuideAnchor(id: id, child: this);
}

const _steps = <String, List<(String, String, String)>>{
  'trips': [
    (
      'route_selector',
      'Choose your route',
      'Choose your departure and destination ports. The swap button reverses the journey.'
    ),
    (
      'date_rail',
      'Pick a travel date',
      'Tap a date to refresh departures. A dot marks dates with scheduled trips.'
    ),
    (
      'schedules_list',
      'Review a sailing',
      'Check the boat, departure, available seats and live fare. Book Seats opens passenger details before you select seats or pay.'
    ),
  ],
  'bookings': [
    (
      'tabs',
      'Find your booking',
      'Switch between bookings awaiting review and confirmed tickets.'
    ),
    (
      'booking_card',
      'Open your boarding pass',
      'Open a confirmed booking to view the signed boarding QR for each passenger.'
    ),
  ],
  'advisories': [
    (
      'advisories_list',
      'Check port notices',
      'Open a notice for its affected route, effective dates and full message. Pull down to refresh.'
    ),
  ],
  'profile': [
    (
      'profile_card',
      'Your passenger details',
      'These details identify your account and contact number.'
    ),
    (
      'account_settings',
      'Keep your details current',
      'Edit profile saves to SeaPass. Changing your password requires your current password.'
    ),
    (
      'travel_history',
      'Past voyages',
      'Your completed trips appear here. A connection error is shown when history cannot load.'
    ),
  ],
};

Future<void> showSeaPassPageGuide(BuildContext context, String page,
    [Map<String, dynamic>? event]) async {
  final action = event?['action'];
  final args = action is Map ? action['args'] : null;
  final target = event?['target'] ?? (args is Map ? args['target'] : null);
  final message = event?['message'] ?? (args is Map ? args['message'] : null);
  final steps = (_steps[page] ?? [])
      .where((step) => target == null || step.$1 == target)
      .toList();
  var shown = false;
  for (var index = 0; index < steps.length; index++) {
    final step = steps[index];
    final anchor = SeaPassGuideAnchor.anchors[step.$1]?.currentContext;
    if (anchor == null || !anchor.mounted) continue;
    await Scrollable.ensureVisible(anchor,
        alignment: .35, duration: const Duration(milliseconds: 180));
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted || !anchor.mounted) return;
    final render = anchor.findRenderObject();
    if (render is! RenderBox || !render.hasSize) continue;
    final rect = render.localToGlobal(Offset.zero) & render.size;
    shown = true;
    final next = await showDialog<bool>(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final colors = Theme.of(dialogContext).colorScheme;
        final visibleRect = rect.intersect(Offset.zero & size).inflate(4);
        return Stack(children: [
          Positioned.fill(
              child: CustomPaint(
                  painter: _Spotlight(visibleRect, colors.primary))),
          Positioned(
            left: 16,
            right: 16,
            top: visibleRect.center.dy > size.height * .5
                ? MediaQuery.paddingOf(dialogContext).top + 20
                : null,
            bottom: visibleRect.center.dy <= size.height * .5
                ? MediaQuery.paddingOf(dialogContext).bottom + 24
                : null,
            child: Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.$2,
                            style:
                                Theme.of(dialogContext).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Text(message is String && message.isNotEmpty
                            ? message
                            : step.$3),
                        const SizedBox(height: 16),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Close')),
                              const SizedBox(width: 8),
                              FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: Text(index == steps.length - 1
                                      ? 'Done'
                                      : 'Next')),
                            ]),
                      ])),
            ),
          ),
        ]);
      },
    );
    if (next != true || !context.mounted) return;
  }
  if (!shown && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('That control is not visible on this screen yet.')));
  }
}

class _Spotlight extends CustomPainter {
  final Rect rect;
  final Color accent;
  _Spotlight(this.rect, this.accent);
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final mask = Path.combine(PathOperation.difference,
        Path()..addRect(Offset.zero & size), Path()..addRRect(hole));
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: .68));
    canvas.drawRRect(
        hole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent);
  }

  @override
  bool shouldRepaint(_Spotlight oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.accent != accent;
}
