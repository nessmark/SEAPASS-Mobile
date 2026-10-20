// JAY-LOCKED 2026-10-20: Center the passenger web app in a phone-sized viewport on desktop; fill the screen on phones. Jay: "the phone part when opening you kinda build a margin so its phone size view". Change only if Jay asks in the session making the change.
(async () => {
  // Flutter's old offline worker can keep serving a previous app after an upgrade.
  // Retire only this app's obsolete worker/cache; keep login and connection storage.
  if ('serviceWorker' in navigator) {
    try {
      const scope = new URL('./', document.baseURI).href;
      const registrations = await navigator.serviceWorker.getRegistrations();
      const obsolete = registrations.filter(registration => registration.scope === scope &&
        (registration.active || registration.waiting || registration.installing)?.scriptURL.includes('/flutter_service_worker.js'));
      if (obsolete.length) {
        await Promise.all(obsolete.map(registration => registration.unregister()));
        const keys = await caches.keys();
        await Promise.all(keys.filter(key => ['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest'].includes(key)).map(key => caches.delete(key)));
        if (navigator.serviceWorker.controller) {
          location.reload();
          return;
        }
      }
    } catch (error) {
      console.warn('SeaPass preview cache migration could not finish.', error.name);
    }
  }
  if (window.self !== window.top) {
    const bootstrap = document.createElement('script');
    bootstrap.src = 'flutter_bootstrap.js?v=' + Date.now();
    bootstrap.async = true;
    document.body.appendChild(bootstrap);
    return;
  }

  const style = document.createElement('style');
  style.textContent = `
    html, body { width: 100%; height: 100%; margin: 0; }
    body {
      display: grid;
      place-items: center;
      box-sizing: border-box;
      min-height: 100dvh;
      padding: 24px 16px;
      overflow: hidden;
      background: #171717;
    }
    iframe {
      display: block;
      width: 390px;
      max-width: 100%;
      height: min(844px, calc(100dvh - 48px));
      border: 1px solid #383838;
      border-radius: 24px;
      box-sizing: border-box;
      background: #080808;
    }
    @media (max-width: 599px) {
      body { padding: 0; }
      iframe { width: 100%; height: 100dvh; border: 0; border-radius: 0; }
    }
  `;
  document.head.appendChild(style);

  const app = document.createElement('iframe');
  app.title = 'SeaPass passenger app';
  app.src = window.location.href;
  app.allow = 'camera; microphone; clipboard-read; clipboard-write';
  document.body.appendChild(app);
})();
