import 'package:flutter/material.dart';

import 'assistant_pages.dart';

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
  void didUpdateWidget(SeaPassGuideAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id && SeaPassGuideAnchor.anchors[oldWidget.id] == anchor) {
      SeaPassGuideAnchor.anchors.remove(oldWidget.id);
    }
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

/// Ids of guide anchors currently rendered anywhere in the app.
Iterable<String> mountedGuideTargets() => SeaPassGuideAnchor.anchors.entries
    .where((entry) => entry.value.currentContext?.mounted == true)
    .map((entry) => entry.key);

bool _guideOpen = false;

/// Spotlights real controls on [page]. A highlight shows one target, a tour
/// shows every target on screen. It only scrolls and points: it never taps,
/// selects a seat, submits a form or pays.
///
/// Returns true when at least one control was shown.
Future<bool> showSeaPassPageGuide(BuildContext context, String page,
    [Map<String, dynamic>? event]) async {
  if (_guideOpen) return false;
  final action = event?['action'];
  final args = action is Map ? action['args'] : null;
  final target = event?['target'] ?? (args is Map ? args['target'] : null);
  final message = event?['message'] ?? (args is Map ? args['message'] : null);
  final steps = (assistantPage(page)?.targets ?? const <AssistantGuideTarget>[])
      .where((step) => target == null || step.id == target)
      .where((step) =>
          SeaPassGuideAnchor.anchors[step.id]?.currentContext?.mounted == true)
      .toList();
  if (steps.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('That control is not visible on this screen yet.')));
    }
    return false;
  }
  _guideOpen = true;
  var shown = false;
  try {
    var index = 0;
    while (index >= 0 && index < steps.length) {
      final step = steps[index];
      final anchor = SeaPassGuideAnchor.anchors[step.id]?.currentContext;
      if (anchor == null || !anchor.mounted || !context.mounted) return shown;
      final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      await Scrollable.ensureVisible(anchor,
          alignment: .35,
          duration: still ? Duration.zero : const Duration(milliseconds: 180));
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted || !anchor.mounted) return shown;
      final render = anchor.findRenderObject();
      if (render is! RenderBox || !render.hasSize) return shown;
      final rect = render.localToGlobal(Offset.zero) & render.size;
      final body = message is String && message.isNotEmpty && steps.length == 1
          ? message
          : step.body;
      shown = true;
      final move = await showDialog<int>(
        context: context,
        useSafeArea: false,
        barrierColor: Colors.transparent,
        builder: (dialogContext) => _GuideCard(
          rect: rect,
          title: step.title,
          body: body,
          index: index,
          total: steps.length,
        ),
      );
      if (move == null || move == 0 || !context.mounted) return shown;
      index += move;
    }
    return shown;
  } finally {
    _guideOpen = false;
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard(
      {required this.rect,
      required this.title,
      required this.body,
      required this.index,
      required this.total});

  final Rect rect;
  final String title;
  final String body;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final visibleRect = rect.intersect(Offset.zero & size).inflate(4);
    final last = index == total - 1;
    return Stack(children: [
      Positioned.fill(
          child: CustomPaint(painter: _Spotlight(visibleRect, colors.primary))),
      Positioned(
        left: 16,
        right: 16,
        top: visibleRect.center.dy > size.height * .5 ? padding.top + 20 : null,
        bottom:
            visibleRect.center.dy <= size.height * .5 ? padding.bottom + 24 : null,
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (total > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('Step ${index + 1} of $total',
                            style: text.labelMedium),
                      ),
                    Text(title, style: text.titleLarge),
                    const SizedBox(height: 12),
                    Text(body),
                    const SizedBox(height: 16),
                    // Wraps onto a second line on narrow phones instead of
                    // pushing a button off the card.
                    OverflowBar(
                        alignment: MainAxisAlignment.end,
                        overflowAlignment: OverflowBarAlignment.end,
                        spacing: 8,
                        overflowSpacing: 4,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, 0),
                              child: const Text('Close')),
                          if (index > 0)
                            TextButton(
                                onPressed: () => Navigator.pop(context, -1),
                                child: const Text('Back')),
                          FilledButton(
                              autofocus: true,
                              onPressed: () =>
                                  Navigator.pop(context, last ? 0 : 1),
                              child: Text(last ? 'Done' : 'Next')),
                        ]),
                  ])),
        ),
      ),
    ]);
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
