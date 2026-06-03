# 🔧 Environment Setup Guide

Complete step-by-step guide to set up and run this project from scratch.

---

## 1. Install Flutter SDK

### Windows
```powershell
# Option A: Using Chocolatey
choco install flutter

# Option B: Manual download
# Download from https://flutter.dev/docs/get-started/install/windows
# Extract to C:\flutter
# Add C:\flutter\bin to your PATH
```

### macOS
```bash
brew install --cask flutter
```

### Linux
```bash
sudo snap install flutter --classic
```

### Verify Installation
```bash
flutter doctor
```
Ensure you see ✓ for Flutter, Android toolchain, and Chrome.

---

## 2. Install Android Studio (For Mobile Builds)

1. Download from [developer.android.com/studio](https://developer.android.com/studio)
2. Install Android SDK (API 21+)
3. Accept licenses:
```bash
flutter doctor --android-licenses
```

---

## 3. Enable Developer Mode (Windows Only)

Required for Flutter plugin symlinks:
```powershell
start ms-settings:developers
```
Toggle **Developer Mode** → ON

---

## 4. Clone & Install Dependencies

```bash
git clone https://github.com/YOUR_USERNAME/Automatic-Document-Verification-System.git
cd Automatic-Document-Verification-System

# Install all Flutter/Dart packages
flutter pub get
```

This installs all packages listed in `pubspec.yaml`:

| Package | Version | Purpose |
|---------|---------|---------|
| `camera` | ^0.11.1 | Live camera preview (mobile) |
| `image_picker` | ^1.1.2 | Pick images from gallery/camera |
| `google_mlkit_text_recognition` | ^0.14.0 | On-device OCR (mobile only) |
| `http` | ^1.3.0 | HTTP client for Groq API calls |
| `path_provider` | ^2.1.5 | Access device file system paths |
| `path` | ^1.9.1 | File path utilities |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |

---

## 5. Get Groq API Key (Free)

1. Go to [console.groq.com](https://console.groq.com)
2. Sign up with Google/GitHub
3. Go to **API Keys** → **Create API Key**
4. Copy the key (format: `gsk_xxxxxxxxxxxx`)
5. You'll paste this into the app at runtime

**Free tier**: ~14,400 tokens/minute — more than enough for testing.

---

## 6. Run the App

### Web (Recommended for Testing)
```bash
flutter run -d chrome
```

### Android Device (USB)
```bash
# 1. Enable USB Debugging on phone:
#    Settings → About Phone → Tap Build Number 7x → Developer Options → USB Debugging
# 2. Connect phone via USB
# 3. Run:
flutter run
```

### Build Android APK
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

---

## 7. Troubleshooting

### "Building with plugins requires symlink support"
→ Enable Developer Mode (Step 3)

### "minSdk too low"
→ Already set to 21 in `android/app/build.gradle.kts`

### "Model decommissioned" error
→ Check [console.groq.com/docs/models](https://console.groq.com/docs/models) for current model IDs and update in `lib/services/groq_service.dart`

### Web camera not working
→ Browser camera requires HTTPS. Run with `--web-port 8080` or test upload mode instead.

### Flutter doctor issues
```bash
flutter doctor -v    # Verbose diagnostics
flutter clean        # Clear build cache
flutter pub get      # Re-fetch dependencies
```
