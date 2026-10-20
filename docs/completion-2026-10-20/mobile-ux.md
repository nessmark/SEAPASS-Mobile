# SeaPass passenger UX and integration, 2026-10-20

Source: /home/kiuren/Projects/NESMARK/mobile. Branch: feat/seapass-completion-2026-10-20.
Owner: Jay. Integration and acceptance: Codex/Finn; initial layout implementation: Antigravity.

## Design decisions

The supplied FuturePro reference informed compact navigation, clear content hierarchy, grouped controls and focused sheets. Its branding and imagery were not copied. The Remote dashboard reference informed grouped account actions and joined information rows. Original app_palette.dart color values remain unchanged.

Desktop previews preserve Jay's locked centered390px phone frame with surrounding margins. Actual phone viewports fill the available width. Source web/index.html and web/phone-preview.js carry the owner lock.

## Implemented

- Compact passenger navigation, clear route swapping, travel-date rail, departure cards and live API fare display. No fabricated port-open badge or hardcoded trip fare.
- Passenger details, category-specific ID requirements, seat selection and itemized checkout. Selected seats are not described as reserved until the server creates a hold.
- Browser checkout opens the real provider URL and polls the authenticated booking. Native checkout uses WebView when available and the same server verification policy.
- A callback URL cannot prove payment. A matching booking must have a verified receipt and confirmed or to_be_confirmed status, with no payment review flag.
- A503 carries the existing reservation ID into retry. Timed out writes are not automatically replayed against another server. An uncertain submission directs the passenger to My Bookings.
- Actual profile PATCH and password PUT requests, loading/validation errors, persisted account changes after server success and truthful history errors.
- Server-signed individual boarding QR payloads are preserved through the model, passenger API and scanner request. Missing signatures show a refresh message instead of an invented QR.
- SeaPass assistant appears by default. Web uses the authenticated embedded surface; Android uses the shared WebView surface. Chat, voice, attachments, history and PDF share the backend contract.
- Assistant trip/date/route/passenger-count arguments reach the actual trip screen and booking form. The passenger still selects seats and confirms payment.
- Current-screen guides scroll to and spotlight real registered controls. Missing controls are reported as unavailable. Guides never submit forms or select seats.
- Browser ID-photo previews use browser image URLs; multipart upload reads those image bytes. Native uploads use the selected local file. Actual browser file selection remains unverified because the authorized browser runtime blocked synthetic chooser population.

## Verification

- Flutter3.47.7, Dart3.13.5, user-local SDK.
- flutter analyze: no issues after final source fixes.
- Full Flutter suite:40tests passed. Includes360px checkout/ticket layouts in light and dark themes, actual PATCH transport, uncertain-write non-replay, payment receipt authority, reservation recovery, scanner signed payload transport and real-control guide scrolling/cleanup.
- Subsequent targeted ticket/layout suite:12tests passed after missing-signature rendering was tightened.
- Backend profile API exercise saved, read back and restored the demo name; invalid phone and wrong current password were rejected. Evidence: webapp/docs/completion-2026-10-20/evidence/profile-api-result.json.
- Release web build and final Brave acceptance are recorded in the root continuation document when complete.

## Remaining acceptance gates

Real merchant checkout/refund/webhook setup, TextLink Android/SIM receipt and physical camera/microphone/file-save behavior are not established by local tests. Android APK compilation is a separate toolchain check; installing SDK dependencies does not prove a native build.
