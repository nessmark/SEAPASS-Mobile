# Payment client integration repair

2026-10-20, Codex/Finn.

The previous browser payment surface generated a fabricated QR and native navigation trusted success query parameters. Both paths now use PaymentVerificationService: the authenticated owned-booking API supplies the matching reference, verified receipt, current status and review flag. Redirects only trigger a check. Waiting, cancelled, expired, missing and review states cannot become a successful payment result.

Browser checkout opens the real backend-issued URL through a direct user action. It has no generated payment QR. Native checkout polls the same booking while displaying the provider page. Closing checkout explains that an already-submitted payment may still complete.

PaymentController returns a minimal owned reservation on503. CheckoutFailure retains its ID and expiry; the coordinator retries that ID. Passenger/seat editing is guarded once a hold exists. An uncertain request without a known ID directs the passenger to My Bookings. ApiService only performs automatic network fallback for reads.

The reservation countdown starts from the server expiry after a hold is created. Before checkout the UI explains when reservation occurs. Refund copy describes recorded review/refund states without asserting an automatic completed refund.

Tests exercise the actual transport and widget: forged/foreign callback hints, missing receipts, mismatched references, review/expired states,503hold reuse, PATCH validation errors, signed scanner payload, real checkout link and waiting until a verified receipt. Actual provider money movement is unverified.

The two broad Antigravity mobile workers were stopped after their saved implementation was audited. Root completed the integration and regressions directly. Their process completion must not be treated as acceptance evidence.
