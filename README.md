# SeaPass Passenger App - Simple Connection Guide

## 🚀 How to Connect in 2 Simple Steps

Whenever you turn on your PC and open the app:

### Step 1: On Your PC
Double-click **`start_server.bat`** in the main project folder.
- This automatically starts the Laravel server on port 8000 and detects your PC's Wi-Fi IP address.
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
2. Run `start_server.bat` (it automatically sets up USB reverse forwarding).
3. In the app, select **USB Debugging (ADB Reverse)** or tap **Auto-Connect Server**.

---

## 🔧 One-Time Setup (Only Do This Once)

If your phone cannot connect over Wi-Fi, make sure Windows isn't blocking port 8000:
1. Right-click **`setup_firewall.bat`** in the project folder and choose **Run as Administrator**.
2. Click **Yes** on the Windows prompt.
3. Done! Port 8000 is now permanently open.

---

## 💡 Quick Tips
- **Same Wi-Fi**: Make sure your phone and PC are connected to the same Wi-Fi network.
- **Mobile Data**: If your phone has Mobile Data (4G/5G) turned on, turn it off while testing on local Wi-Fi so the phone routes to your local PC.
