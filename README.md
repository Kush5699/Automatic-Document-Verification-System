# 🪪 ID Scanner — Automatic Document Verification System

A **Flutter** cross-platform app (Mobile + Web) that scans identity cards via camera or image upload and automatically extracts guest details using **AI-powered OCR & entity extraction**.

Built for motel/hotel front-desk staff to speed up guest check-in by eliminating manual form filling.

---

## ✨ Features

- 📷 **Live Camera Scan** — Capture ID cards in real-time (mobile)
- 📁 **Upload Image** — Pick ID card images from gallery/files
- 🔍 **On-device OCR** — Google ML Kit text recognition (mobile, zero-cost)
- 🤖 **AI Entity Extraction** — Groq API with Llama models for intelligent field parsing
- 🌐 **Web Support** — Groq Vision API (Llama 4 Scout) for browser-based scanning
- 📝 **Raw OCR Display** — View exactly what text was detected for verification
- 🌍 **Any Country, Any Format** — Works with driving licenses, passports, national IDs worldwide
- ⚡ **Sub-2s Processing** — Fast enough for real-time form filling

## 📋 Extracted Fields

| Field | Example |
|-------|---------|
| First Name | John |
| Last Name | Smith |
| Date of Birth | 03/15/1990 |
| Gender | Male |
| Address | 123 Main Street |
| City | Montgomery |
| State | Alabama |
| Postal Code | 36104 |
| Country | United States |
| ID Number | S530-1234-5678 |
| ID Type | Driving License |
| Expiry Date | 03/15/2028 |
| Nationality | American |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ID SCANNER APP                            │
├──────────────────────┬──────────────────────────────────────┤
│   📱 MOBILE MODE     │   🌐 WEB MODE                       │
├──────────────────────┼──────────────────────────────────────┤
│ Camera / Upload      │ Browser Camera / Upload              │
│        ↓             │        ↓                             │
│ Google ML Kit OCR    │ Groq Vision API                      │
│ (on-device, free)    │ (Llama 4 Scout 17B)                  │
│        ↓             │        ↓                             │
│ Raw OCR Text         │ Raw Text + Extracted Fields          │
│        ↓             │ (single API call)                    │
│ Groq Text LLM       │                                      │
│ (Llama 3.3 70B)     │                                      │
│        ↓             │        ↓                             │
│ Extracted Fields     │ Extracted Fields                     │
└──────────────────────┴──────────────────────────────────────┘
```

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.35+ (Dart 3.9+) |
| Mobile OCR | Google ML Kit Text Recognition |
| AI Extraction | Groq API (Llama 3.3 70B + Llama 4 Scout 17B) |
| Camera | Flutter Camera Plugin |
| Image Picker | Flutter Image Picker |
| HTTP Client | Dart `http` package |
| Min Android SDK | 21 (Android 5.0+) |

---

## 📦 Dependencies

All dependencies are managed via `pubspec.yaml`:

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.8
  camera: ^0.11.1              # Live camera preview (mobile)
  image_picker: ^1.1.2         # Gallery/camera image picking
  google_mlkit_text_recognition: ^0.14.0  # On-device OCR (mobile)
  http: ^1.3.0                 # HTTP client for Groq API
  path_provider: ^2.1.5        # File system paths
  path: ^1.9.1                 # Path utilities
```

---

## 🚀 Setup & Run

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| **Flutter SDK** | 3.35+ | [flutter.dev/get-started](https://flutter.dev/docs/get-started/install) |
| **Android Studio** | Latest | [developer.android.com](https://developer.android.com/studio) (for Android builds) |
| **Chrome** | Latest | For web testing |
| **Groq API Key** | Free | [console.groq.com](https://console.groq.com) |

### Step 1: Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/Automatic-Document-Verification-System.git
cd Automatic-Document-Verification-System
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Get Groq API Key (Free)

1. Go to [console.groq.com](https://console.groq.com)
2. Sign up / Log in
3. Navigate to **API Keys** → **Create API Key**
4. Copy the key (starts with `gsk_...`)

### Step 4: Run the App

#### 🌐 Web (Chrome)
```bash
flutter run -d chrome
```

#### 📱 Android (USB device)
```bash
# Connect your Android phone via USB with USB Debugging enabled
flutter run
```

#### 📱 Android (Build APK)
```bash
flutter build apk --debug
# APK will be at: build/app/outputs/flutter-apk/app-debug.apk
```

### Step 5: Use the App

1. Enter your **Groq API key** on the home screen
2. Choose **Live Scan** (camera) or **Upload Image** (gallery)
3. View the **Raw OCR Text** to verify detection accuracy
4. Review the **Extracted Fields** auto-filled by AI

---

## 📂 Project Structure

```
lib/
├── main.dart                          # App entry, theme, routes
├── models/
│   ├── identity_data.dart             # Data model (13 fields + JSON parsing)
│   └── image_holder.dart              # Cross-platform image data holder
├── screens/
│   ├── home_screen.dart               # Home: API key + scan/upload options
│   ├── camera_screen.dart             # Live camera preview (mobile only)
│   └── result_screen.dart             # Results: OCR text + extracted fields
└── services/
    ├── ocr_service.dart               # Google ML Kit OCR wrapper (mobile)
    ├── ocr_service_stub.dart          # Web stub (OCR not used on web)
    └── groq_service.dart              # Groq API: text LLM + vision model
```

---

## ⚙️ Platform-Specific Notes

### Android
- **Min SDK**: 21 (set in `android/app/build.gradle.kts`)
- **Permissions**: Camera, Internet, Storage (in `AndroidManifest.xml`)
- **Developer Mode**: Required on Windows for Flutter plugin symlinks

### Web
- Google ML Kit OCR is **not available** on web
- Web mode uses **Groq Vision API** (sends image as base64) instead
- Camera uses browser's native camera via `image_picker`

---

## 🔑 API Configuration

The app uses **Groq API** for AI processing:

| Mode | Model | Purpose |
|------|-------|---------|
| Mobile (text) | `llama-3.3-70b-versatile` | Extract fields from OCR text |
| Web (vision) | `meta-llama/llama-4-scout-17b-16e-instruct` | Read image + extract fields |

**Free tier limits**: ~14,400 tokens/minute — sufficient for testing.

---

## 🧪 Testing with Sample IDs

Place sample ID card images in the project root or use the `dataset_1/` folder.
Upload them via the **"Upload Image"** option to test extraction accuracy.

---

## 📄 License

This project is for educational and testing purposes.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
