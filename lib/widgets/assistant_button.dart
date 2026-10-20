import 'package:flutter/material.dart';
import '../services/assistant_service.dart';
import 'assistant/assistant_surface_stub.dart'
    if (dart.library.html) 'assistant/assistant_surface_web.dart'
    if (dart.library.io) 'assistant/assistant_surface_native.dart';

/// Shared, authenticated SeaPass assistant. The model can request only named app pages.
class SeaPassAssistantButton extends StatelessWidget {
  final String pageLabel;
  final String pagePath;
  final ValueChanged<String> onNavigate;
  final ValueChanged<Map<String, dynamic>>? onNavigation;
  final VoidCallback? onGuide;
  final ValueChanged<Map<String, dynamic>>? onGuideAction;
  const SeaPassAssistantButton({super.key, required this.pageLabel, required this.pagePath, required this.onNavigate, this.onNavigation, this.onGuide, this.onGuideAction});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: const Text('Ask SeaPass'),
      onPressed: () {
        // Keep one authenticated bootstrap per opening. Keyboard/viewport changes
        // can rebuild the sheet while the passenger is composing a message.
        final bootstrap = AssistantService.bootstrap(
          label: pageLabel,
          path: pagePath,
          theme: Theme.of(context).brightness == Brightness.light ? 'light' : 'dark',
        );
        showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        clipBehavior: Clip.antiAlias,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: FutureBuilder<Map<String, dynamic>>(
            future: bootstrap,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('SeaPass assistant'), const SizedBox(height: 16), Text(snapshot.error.toString().replaceFirst('Exception: ', '')), TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Close'))]));
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return AssistantSurface(
                uri: AssistantService.embedUri,
                config: {
                  ...snapshot.data!,
                  'theme': Theme.of(context).brightness == Brightness.light ? 'light' : 'dark',
                },
                onEvent: (event) {
                  final type = event['type'];
                  if (type == 'close') Navigator.pop(sheetContext);
                  if (type == 'navigate') {
                    final page = event['page'] as String? ?? '';
                    if (['trips', 'bookings', 'advisories', 'profile', 'scanner'].contains(page)) {
                      Navigator.pop(sheetContext);
                      if (onNavigation != null) {
                        onNavigation!(event);
                      } else {
                        onNavigate(page);
                      }
                    }
                  }
                  if (type == 'guide') {
                    Navigator.pop(sheetContext);
                    if (onGuideAction != null) { onGuideAction!(event); }
                    else if (onGuide != null) { onGuide!(); } else {
                      showDialog<void>(context: context, builder: (context) => AlertDialog(title: Text(pageLabel), content: Text(_guideText(pagePath)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))]));
                    }
                  }
                },
              );
            },
          ),
        ),
        );
      },
    );
  }

  String _guideText(String page) => switch (page) {
    'bookings' => 'Your bookings appear here. Open a confirmed booking to view its boarding QR. A discounted ticket may need a staff ID check first. Payment and refund status come from the booking record.',
    'advisories' => 'Read the latest route notices before travelling. Open a notice for the complete message, affected route and effective dates. Confirm urgent changes with port staff.',
    'profile' => 'Your account details and sign-out controls are here. Keep your contact information current so port staff can reach you.',
    _ => 'Choose your origin, destination and travel date to see upcoming departures. Open a trip to check the boat, available seats and fare, then select seats and review your booking before checkout.',
  };
}
