import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/api_service.dart';
import '../../services/payment_verification_service.dart';
import '../../widgets/app_palette.dart';
import 'paymongo_web_bridge.dart';

enum PaymentResult { success, cancelled, failed }

class PayMongoWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String referenceNumber;
  final double totalAmount;
  final PaymentVerificationService verificationService;
  final ValueChanged<String>? openCheckout;
  const PayMongoWebViewScreen({
    super.key, required this.checkoutUrl, required this.referenceNumber, required this.totalAmount,
    this.verificationService = const PaymentVerificationService(), this.openCheckout,
  });
  @override
  State<PayMongoWebViewScreen> createState() => _PayMongoWebViewScreenState();
}

class _PayMongoWebViewScreenState extends State<PayMongoWebViewScreen> {
  WebViewController? _controller;
  Timer? _poll;
  bool _checking = false;
  bool _finished = false;
  String _notice = 'Complete payment in secure checkout. SeaPass will verify the booking automatically.';
  CheckoutVerification _status = CheckoutVerification.waiting;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.checkoutUrl);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) {
      _notice = 'The checkout link is unavailable. Return to your booking and try again.';
      _status = CheckoutVerification.missing;
      return;
    }
    if (!kIsWeb && WebViewPlatform.instance != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (request) {
            if (PaymentVerificationService.isReturnUrl(request.url, Uri.parse(ApiService.baseUrl))) {
              unawaited(_verify());
              return NavigationDecision.prevent;
            }
            final next = Uri.tryParse(request.url);
            return next != null && ['http', 'https'].contains(next.scheme)
              ? NavigationDecision.navigate : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => _notice = 'Checkout could not load. Check your connection or return to My Bookings.');
            }
          },
        ))
        ..loadRequest(uri);
    }
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _verify());
  }

  @override
  void dispose() { _poll?.cancel(); super.dispose(); }

  Future<void> _verify() async {
    if (_checking || _finished || !mounted) return;
    setState(() => _checking = true);
    try {
      final status = await widget.verificationService.check(widget.referenceNumber);
      if (!mounted || _finished) return;
      if (status == CheckoutVerification.paid) {
        _finished = true;
        _poll?.cancel();
        Navigator.of(context).pop(PaymentResult.success);
        return;
      }
      setState(() {
        _status = status;
        _notice = switch (status) {
          CheckoutVerification.cancelled => 'This booking was cancelled. Check its payment and refund details in My Bookings.',
          CheckoutVerification.expired => 'This reservation expired. Check My Bookings if you already submitted a payment.',
          CheckoutVerification.review => 'Your payment needs a port staff review. Check My Bookings before paying again.',
          CheckoutVerification.missing => 'This booking could not be found. Check My Bookings before paying again.',
          _ => 'Payment has not been verified yet. Complete checkout, then check again.',
        };
      });
      if (status != CheckoutVerification.waiting) _poll?.cancel();
    } catch (_) {
      if (mounted) setState(() => _notice = 'Payment status could not be verified. Check your connection and My Bookings before paying again.');
    } finally {
      if (mounted && !_finished) setState(() => _checking = false);
    }
  }

  Future<void> _leave() async {
    final leave = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Leave checkout?'),
      content: const Text('A payment you already submitted may still complete. Check My Bookings before paying again.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave checkout')),
      ],
    ));
    if (leave == true && mounted) Navigator.of(context).pop(PaymentResult.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final waiting = _status == CheckoutVerification.waiting;
    final status = Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_notice, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: _checking ? null : _verify,
        icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded),
        label: const Text('Check payment status')),
    ]));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) unawaited(_leave()); },
      child: Scaffold(
        backgroundColor: colors.canvas,
        appBar: AppBar(title: const Text('Secure checkout'), automaticallyImplyLeading: false,
          actions: [IconButton(tooltip: 'Leave checkout', onPressed: _leave, icon: const Icon(Icons.close_rounded))]),
        body: _controller != null
          ? Column(children: [Expanded(child: WebViewWidget(controller: _controller!)), status])
          : SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 20),
              Icon(Icons.lock_outline_rounded, color: colors.accent, size: 42),
              const SizedBox(height: 20),
              Text('₱${widget.totalAmount.toStringAsFixed(2)}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Reference ${widget.referenceNumber}', textAlign: TextAlign.center),
              const SizedBox(height: 28),
              const Text('Open PayMongo to choose a payment method. Keep this screen open while your payment is verified.', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: waiting ? () => (widget.openCheckout ?? openWebCheckoutUrl)(widget.checkoutUrl) : null,
                icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open secure checkout')),
              status,
            ])),
      ),
    );
  }
}
