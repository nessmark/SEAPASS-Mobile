class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class CheckoutFailure extends ApiException {
  final int? bookingId;
  final DateTime? expiresAt;
  final bool outcomeUnknown;
  CheckoutFailure(super.message,
      {this.bookingId, this.expiresAt, this.outcomeUnknown = false});

  factory CheckoutFailure.fromPayload(dynamic payload) {
    final data = payload is Map ? payload : const {};
    final booking = data['booking'] is Map ? data['booking'] as Map : const {};
    return CheckoutFailure(
        data['message']?.toString() ??
            'Checkout could not open. Check My Bookings before trying again.',
        bookingId: int.tryParse(booking['id']?.toString() ?? ''),
        expiresAt: DateTime.tryParse(
            booking['reservation_expires_at']?.toString() ?? ''));
  }
}
