import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import 'api_service.dart';

enum CheckoutVerification { waiting, paid, cancelled, expired, review, missing }

/// A provider redirect is a hint. Only an owned booking returned by SeaPass proves payment.
class PaymentVerificationService {
  final http.Client? client;
  const PaymentVerificationService({this.client});

  Future<CheckoutVerification> check(String reference) async {
    final response = await ApiService.request(
      method: 'GET',
      endpoint: '/api/bookings',
      client: client,
    );
    if (response.statusCode != 200) {
      throw ApiException(
          'Payment status could not be verified. Check My Bookings before paying again.');
    }
    final data = jsonDecode(response.body);
    if (data is! Map || data['all'] is! List) {
      throw ApiException('SeaPass returned an incomplete payment status.');
    }
    for (final record in data['all'] as List) {
      if (record is Map &&
          record['reference_number']?.toString() == reference) {
        return classify(Map<String, dynamic>.from(record));
      }
    }
    return CheckoutVerification.missing;
  }

  static CheckoutVerification classify(Map<String, dynamic> booking) {
    if (booking['payment_review_required'] == true) {
      return CheckoutVerification.review;
    }
    final status = booking['status']?.toString().toLowerCase();
    if (status == 'cancelled') return CheckoutVerification.cancelled;
    if (status == 'expired') return CheckoutVerification.expired;
    final receipt = booking['payment_received_at'];
    if ((status == 'confirmed' || status == 'to_be_confirmed') &&
        receipt is String &&
        DateTime.tryParse(receipt) != null) {
      return CheckoutVerification.paid;
    }
    return CheckoutVerification.waiting;
  }

  static bool isReturnUrl(String value, Uri apiBase) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.hasAuthority &&
        uri.origin == apiBase.origin &&
        const ['/payment/success', '/payment/cancel'].contains(uri.path);
  }
}
