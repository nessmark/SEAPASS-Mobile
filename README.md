# SeaPass — Passenger App

The **Flutter** passenger app for SeaPass: browse trips, pick seats, pay, and carry a QR ticket
for the Surigao ⇄ San Jose lancha route.

This repository is the `mobile/` half of the project. The Laravel API and admin dashboard live in
[nessmark/SEAPASS-Web](https://github.com/nessmark/SEAPASS-Web); both are split out of the
[nessmark/seapass](https://github.com/nessmark/seapass) monorepo.

Targets Android (primary) and the web build used for demos.

---

## 🚀 How to Connect in 2 Simple Steps

Whenever you turn on your PC and open the app:

### Step 1: On Your PC
In the **SEAPASS-Web** repo, double-click **`scripts/start_server.bat`**.
- It frees port 8000, sets up USB reverse forwarding, starts the ngrok tunnel, and runs the Laravel server.
- *(Keep this window open while testing)*.

### Step 2: On Your Phone
Open the SeaPass app:
- Tap **Auto-Connect Server** on the screen.
- Or tap the top-right Settings icon ⚙️ and select **Wi-Fi (Auto-Connect Server)**.
- The app will automatically find your PC on the Wi-Fi network and connect!

---

## ⚡ Using USB Cable Instead? (Zero-Setup Alternative)
If you connect your phone to your PC via USB cable:
1. Plug in your USB cable (with USB debugging enabled).
2. Run `scripts/start_server.bat` from the web repo (it automatically sets up USB reverse forwarding).
3. In the app, select **USB Debugging (ADB Reverse)** or tap **Auto-Connect Server**.

---

## 🔧 One-Time Setup (Only Do This Once)

If your phone cannot connect over Wi-Fi, make sure Windows isn't blocking port 8000:
1. Right-click **`scripts/setup_firewall.bat`** (web repo) and choose **Run as Administrator**.
2. Click **Yes** on the Windows prompt.
3. Done! Port 8000 is now permanently open.

---

## 🛠 Building and running

```powershell
flutter pub get
flutter run                 # connected Android device or emulator
flutter run -d chrome       # web build used for demos
```

Point the app at a specific backend without editing code:

```powershell
flutter run --dart-define=SEAPASS_API_BASE_URL=http://192.168.1.50:8000/api
```

Otherwise the endpoint comes from `lib/config/api_config.dart`:

| Mode | Host |
|---|---|
| USB (ADB Reverse) | `127.0.0.1:8000` |
| Android Emulator | `10.0.2.2:8000` |
| Wi-Fi (Auto-Connect Server) | scans the LAN for the PC running Laravel |
| Production Server | the project's free ngrok domain — **not** `api.seapass.ph`, which does not exist yet |

---

## 💡 Quick Tips
- **Same Wi-Fi**: Make sure your phone and PC are connected to the same Wi-Fi network.
- **Mobile Data**: If your phone has Mobile Data (4G/5G) turned on, turn it off while testing on local Wi-Fi so the phone routes to your local PC.
- **Notifications**: there are no push notifications in the app — advisories and booking updates are
  delivered by email from the backend, which needs `php artisan queue:work` running to send them.
