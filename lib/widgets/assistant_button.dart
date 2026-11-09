import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/assistant_service.dart';
import 'assistant/assistant_navigation.dart';
import 'assistant/assistant_pages.dart';
import 'assistant/page_guide.dart';
import 'assistant/assistant_surface_stub.dart'
    if (dart.library.html) 'assistant/assistant_surface_web.dart'
    if (dart.library.io) 'assistant/assistant_surface_native.dart';

typedef AssistantBootstrapper = Future<Map<String, dynamic>> Function({
  required String label,
  required String path,
  required String theme,
  String? details,
  Iterable<String>? mountedTargets,
});

typedef AssistantSurfaceBuilder = Widget Function(
    BuildContext context, Uri uri, Map<String, dynamic> config, ValueChanged<Map<String, dynamic>> onEvent);

Future<Map<String, dynamic>> _defaultBootstrap({
  required String label,
  required String path,
  required String theme,
  String? details,
  Iterable<String>? mountedTargets,
}) =>
    AssistantService.bootstrap(
        label: label, path: path, theme: theme, details: details, mountedTargets: mountedTargets);

Widget _defaultSurface(
        BuildContext context, Uri uri, Map<String, dynamic> config, ValueChanged<Map<String, dynamic>> onEvent) =>
    AssistantSurface(uri: uri, config: config, onEvent: onEvent);

/// Shared, authenticated SeaPass assistant launcher.
///
/// Sits in the top bar of every passenger screen so it never covers a screen's
/// own buttons. The model can only open named passenger tabs, prefill a trip
/// search, or point at controls on the current screen.
class SeaPassAssistantButton extends StatelessWidget {
  final String pageLabel;
  final String pagePath;

  /// Legacy tab switch callback. Prefer [onNavigation].
  final ValueChanged<String>? onNavigate;

  /// Receives a sanitized `navigate` event: `{type, page, args}` where args only
  /// holds booking prefill fields.
  final ValueChanged<Map<String, dynamic>>? onNavigation;
  final VoidCallback? onGuide;
  final ValueChanged<Map<String, dynamic>>? onGuideAction;

  /// Icon-only button for pushed screens with a busy top bar.
  final bool compact;

  /// Short description of what the screen shows right now, read when opened.
  final String Function()? details;

  /// Asked before the assistant takes the passenger away from this screen.
  final Future<bool> Function(BuildContext context)? confirmLeave;

  final AssistantBootstrapper bootstrapper;
  final AssistantSurfaceBuilder surfaceBuilder;
  final Duration readyTimeout;

  const SeaPassAssistantButton({
    super.key,
    required this.pageLabel,
    required this.pagePath,
    this.onNavigate,
    this.onNavigation,
    this.onGuide,
    this.onGuideAction,
    this.compact = false,
    this.details,
    this.confirmLeave,
    this.bootstrapper = _defaultBootstrap,
    this.surfaceBuilder = _defaultSurface,
    this.readyTimeout = const Duration(seconds: 30),
  });

  static bool _sheetOpen = false;

  /// True while an assistant sheet is showing. One sheet at a time.
  static bool get isOpen => _sheetOpen;

  @override
  Widget build(BuildContext context) {
    const label = 'Ask SeaPass';
    if (compact) {
      return IconButton(
        tooltip: label,
        icon: const Icon(Icons.auto_awesome_outlined, size: 22),
        onPressed: () => open(context),
      );
    }
    return Tooltip(
      message: 'Open the SeaPass assistant',
      child: TextButton(onPressed: () => open(context), child: const Text(label)),
    );
  }

  Future<void> open(BuildContext context) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final theme = Theme.of(context).brightness == Brightness.light ? 'light' : 'dark';
    // Read once per opening. Keyboard and viewport changes rebuild the sheet
    // while the passenger is typing, and must not restart the session.
    final screenDetails = details?.call();
    final mounted = mountedGuideTargets().toList();
    Future<Map<String, dynamic>> load() => bootstrapper(
        label: pageLabel, path: pagePath, theme: theme, details: screenDetails, mountedTargets: mounted);
    final hasGuide = assistantTargetsFor(pagePath, mounted: mounted).isNotEmpty;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        clipBehavior: Clip.antiAlias,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .9,
          child: AssistantSheet(
            load: load,
            uri: AssistantService.embedUri,
            surfaceBuilder: surfaceBuilder,
            readyTimeout: readyTimeout,
            canShowGuide: hasGuide,
            onClose: () => _closeSheet(sheetContext),
            onSignIn: () {
              _closeSheet(sheetContext);
              Navigator.of(context, rootNavigator: true)
                  .pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
            },
            onShowGuide: () => _handleGuide(context, sheetContext, const {'type': 'guide'}),
            onEvent: (event) => _handleEvent(context, sheetContext, event),
          ),
        ),
      );
    } finally {
      _sheetOpen = false;
    }
  }

  /// Pops the sheet only while it is still the top route. A late message from
  /// the page must never pop the screen underneath.
  static bool _closeSheet(BuildContext sheetContext) {
    if (!sheetContext.mounted) return false;
    final route = ModalRoute.of(sheetContext);
    if (route == null || !route.isCurrent) return false;
    Navigator.of(sheetContext).pop();
    return true;
  }

  void _handleEvent(BuildContext context, BuildContext sheetContext, Map<String, dynamic> event) {
    switch (event['type']) {
      case 'close':
        _closeSheet(sheetContext);
      case 'navigate':
        _handleNavigate(context, sheetContext, event);
      case 'guide':
        _handleGuide(context, sheetContext, event);
    }
  }

  Future<void> _handleNavigate(BuildContext context, BuildContext sheetContext, Map<String, dynamic> event) async {
    final request = AssistantNavigationRequest.fromEvent(event);
    if (request == null) return;
    if (confirmLeave != null) {
      if (!sheetContext.mounted) return;
      final leave = await confirmLeave!(sheetContext);
      if (!leave) return;
    }
    if (!_closeSheet(sheetContext) || !context.mounted) return;
    final sanitized = {'type': 'navigate', 'page': request.page, 'args': request.prefill};
    if (onNavigation != null) {
      onNavigation!(sanitized);
    } else if (onNavigate != null) {
      onNavigate!(request.page);
    } else {
      // Pushed screens hand the request to the passenger shell under them.
      AssistantNavigationBus.pending.value = request;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _handleGuide(BuildContext context, BuildContext sheetContext, Map<String, dynamic> event) {
    if (!_closeSheet(sheetContext) || !context.mounted) return;
    if (onGuideAction != null) {
      onGuideAction!(event);
    } else if (onGuide != null) {
      onGuide!();
    } else {
      showSeaPassPageGuide(context, pagePath, event);
    }
  }
}

class _Failure {
  const _Failure(this.title, this.message, this.icon, {this.retry = true, this.signIn = false});

  factory _Failure.from(AssistantUnavailable error) => _Failure(
        error.title,
        error.message,
        switch (error.kind) {
          AssistantFailureKind.offline || AssistantFailureKind.unreachable => Icons.cloud_off_rounded,
          AssistantFailureKind.signedOut => Icons.lock_outline_rounded,
          _ => Icons.info_outline_rounded,
        },
        retry: error.canRetry,
        signIn: error.kind == AssistantFailureKind.signedOut,
      );

  final String title;
  final String message;
  final IconData icon;
  final bool retry;
  final bool signIn;
}

/// The sheet body: loading, the embedded page, or one clear failure state.
/// Every wait is bounded, so the passenger never sees an endless spinner.
class AssistantSheet extends StatefulWidget {
  const AssistantSheet({
    super.key,
    required this.load,
    required this.uri,
    required this.onEvent,
    required this.onClose,
    required this.onSignIn,
    required this.onShowGuide,
    this.surfaceBuilder = _defaultSurface,
    this.readyTimeout = const Duration(seconds: 30),
    this.loadTimeout = const Duration(seconds: 25),
    this.canShowGuide = true,
  });

  final Future<Map<String, dynamic>> Function() load;
  final Uri uri;
  final ValueChanged<Map<String, dynamic>> onEvent;
  final VoidCallback onClose;
  final VoidCallback onSignIn;
  final VoidCallback onShowGuide;
  final AssistantSurfaceBuilder surfaceBuilder;
  final Duration readyTimeout;
  final Duration loadTimeout;
  final bool canShowGuide;

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  int _attempt = 0;
  Map<String, dynamic>? _config;
  _Failure? _failure;
  bool _ready = false;
  Timer? _readyTimer;

  static const _tooSlow = _Failure('Taking too long',
      'The assistant did not open in time. Check your connection and try again.', Icons.cloud_off_rounded);
  static const _pageFailed = _Failure('Cannot reach SeaPass',
      'The assistant page could not load. Check your connection and try again.', Icons.cloud_off_rounded);
  static const _unsupported = _Failure('Assistant unavailable',
      'The assistant needs the SeaPass Android app or a web browser. The page guide still works.',
      Icons.info_outline_rounded,
      retry: false);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _readyTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final attempt = ++_attempt;
    _readyTimer?.cancel();
    if (attempt > 1) {
      setState(() {
        _config = null;
        _failure = null;
        _ready = false;
      });
    }
    try {
      final config = await widget.load().timeout(widget.loadTimeout);
      if (!mounted || attempt != _attempt) return;
      setState(() => _config = config);
      _readyTimer = Timer(widget.readyTimeout, () {
        if (mounted && attempt == _attempt && !_ready) setState(() => _failure = _tooSlow);
      });
    } catch (error) {
      if (!mounted || attempt != _attempt) return;
      setState(() => _failure = _Failure.from(AssistantService.classify(error)));
    }
  }

  void _onSurfaceEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    switch (event['type']) {
      case 'ready':
        _readyTimer?.cancel();
        if (!_ready) setState(() => _ready = true);
      case 'surface_error':
        _readyTimer?.cancel();
        setState(() => _failure = event['reason'] == 'unsupported' ? _unsupported : _pageFailed);
      default:
        widget.onEvent(event);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) return _buildFailure(context, failure);
    final config = _config;
    if (config == null) return _buildLoading(context);
    return Stack(children: [
      Positioned.fill(
        child: KeyedSubtree(
          key: ValueKey('assistant-surface-$_attempt'),
          child: widget.surfaceBuilder(context, widget.uri, config, _onSurfaceEvent),
        ),
      ),
      if (!_ready) Positioned.fill(child: _buildLoading(context)),
    ]);
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
      child: Row(children: [
        Expanded(child: Text('SeaPass assistant', style: Theme.of(context).textTheme.titleMedium)),
        IconButton(tooltip: 'Close assistant', onPressed: widget.onClose, icon: const Icon(Icons.close_rounded)),
      ]),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(children: [
        _header(context),
        const Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Opening the assistant…'),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildFailure(BuildContext context, _Failure failure) {
    final theme = Theme.of(context);
    return Column(children: [
      _header(context),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(failure.icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(failure.title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(failure.message, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            if (failure.signIn)
              FilledButton(onPressed: widget.onSignIn, child: const Text('Sign in'))
            else if (failure.retry)
              FilledButton(onPressed: _start, child: const Text('Try again')),
            if (widget.canShowGuide && !failure.signIn) ...[
              const SizedBox(height: 8),
              OutlinedButton(onPressed: widget.onShowGuide, child: const Text('Show me this page')),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: widget.onClose, child: const Text('Close')),
          ]),
        ),
      ),
    ]);
  }
}
