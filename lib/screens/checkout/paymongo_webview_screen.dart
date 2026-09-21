import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../widgets/app_palette.dart';

enum PaymentResult {
  success,
  cancelled,
  failed,
}

class PayMongoWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String referenceNumber;
  final double totalAmount;

  const PayMongoWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.referenceNumber,
    required this.totalAmount,
  });

  @override
  State<PayMongoWebViewScreen> createState() => _PayMongoWebViewScreenState();
}

class _PayMongoWebViewScreenState extends State<PayMongoWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  int _loadingProgress = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppPalette.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!_isDisposed && mounted) {
              setState(() {
                _loadingProgress = progress;
                if (progress >= 100) {
                  _isLoading = false;
                }
              });
            }
          },
          onPageStarted: (String url) {
            _checkRedirectUrls(url);
          },
          onPageFinished: (String url) {
            if (!_isDisposed && mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _checkRedirectUrls(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('PayMongo WebView resource error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final handled = _checkRedirectUrls(request.url);
            if (handled) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.checkoutUrl),
        headers: const {
          'ngrok-skip-browser-warning': '1',
        },
      );
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  bool _checkRedirectUrls(String url) {
    final lower = url.toLowerCase();

    // 1. Success redirection detected
    if (lower.contains('/payment/success') ||
        lower.contains('status=paid') ||
        lower.contains('status=success') ||
        lower.contains('paid=true')) {
      if (mounted) {
        Navigator.of(context).pop(PaymentResult.success);
      }
      return true;
    }

    // 2. Cancellation redirection detected
    if (lower.contains('/payment/cancel') ||
        lower.contains('status=cancelled') ||
        lower.contains('status=canceled')) {
      if (mounted) {
        Navigator.of(context).pop(PaymentResult.cancelled);
      }
      return true;
    }

    return false;
  }

  Future<bool> _onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text(
          'Are you sure you want to exit? If you have not completed the QR scan in your GCash / banking app, your payment will not be recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay & Pay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.danger,
              foregroundColor: AppPalette.white,
            ),
            child: const Text('Cancel Payment'),
          ),
        ],
      ),
    );

    return shouldLeave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final confirm = await _onWillPop();
        if (confirm && mounted) {
          navigator.pop(PaymentResult.cancelled);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PayMongo QR Checkout',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                'Ref: #${widget.referenceNumber} • ₱${widget.totalAmount.toStringAsFixed(2)}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppColors.of(context).text3),
              ),
            ],
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close Checkout',
              onPressed: () async {
                final navigator = Navigator.of(context);
                final confirm = await _onWillPop();
                if (confirm && mounted) {
                  navigator.pop(PaymentResult.cancelled);
                }
              },
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3.0),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress / 100 : null,
                    backgroundColor: AppColors.of(context).surface2,
                    color: AppColors.of(context).accent,
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: AppColors.of(context).surface,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                            color: AppColors.of(context).accent),
                        const SizedBox(height: 16),
                        Text(
                          'Loading PayMongo QR Checkout...',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Please prepare your GCash or QR Ph app',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
