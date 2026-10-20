
## 🔒 Jay locks

- 2026-10-20: Desktop passenger web preview is centered at phone size with margins; real phone widths fill the screen. Locked in web/index.html and web/phone-preview.js. Source launcher is copied into build/web for the current preview.


## 2026-10-20 [codex/Finn] completion branch

Branch feat/seapass-completion-2026-10-20, original head7de6902. Preserve copied-worktree mode-only changes; use git -c core.filemode=false and stage only actual task content. Preview http://127.0.0.1:5185/ via user service seapass-mobile-preview.service; local backend8000 via seapass-preview.service. Normal demo login marilou.bautista@example.com / password, no authentication bypass code.

Current source integrates compact UX, actual profile/password transport, live fares, signed passenger QR, default assistant, navigation prefill, real-control spotlight guides and server-verified checkout. Forty-one Flutter tests passed and final analyzer is clean. Root docs/completion-2026-10-20/mobile-ux.md and payment-repair.md describe actual behavior and remaining gates. Final web build/Brave acceptance is recorded in webapp/docs/completion-2026-10-20/CONTINUE.md when complete. app_palette.dart color values unchanged.

Never call real PayMongo/refunds, TextLink SIM delivery or physical mic/camera/file-save verified based on local mock tests. Native APK compilation is separate from web compilation and dependency installation. All Agy source workers are terminal; root completed the final mobile integration directly. SDK download/build jobs live outside Git in ~/.local/share/seapass-preview/tasks/.

Final root audit removed random/fabricated seat map fallback. Missing maps block payment and offer refresh; 41 tests and analyzer pass, final release web build passes. Local HTTP mock checkout to verified receipt/two signed tickets passed; actual phone Bookings/two QR screens reviewed at360px. Full browser checkout later passed after official bridge recovery and a SQLite preview locking fix. Continuation evidence is in the sibling webapp completion folder.
