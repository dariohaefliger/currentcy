# Currentcy — Currency Conversion App  
[![Flutter](https://img.shields.io/badge/Flutter-3.38-blue?logo=flutter&logoColor=white)]()
[![Release](https://img.shields.io/badge/Release-1.0.0-success)]()
[![License](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-brightgreen)]()  
[![Platform](https://img.shields.io/badge/Android-Supported-green?logo=android)]()
[![iOS](https://img.shields.io/badge/iOS-Not%20Supported-red?logo=apple&logoColor=white)]()
[![Status](https://img.shields.io/badge/Development-Part%20Time-orange)]()   

A professional-grade mobile application for converting currencies with **live exchange rates**, **multi-currency views**, and **5-day historical charts**.  
Designed for **private users** of all kinds, especially **travelers** who need fast and reliable exchange calculations.

---

## Features

### Primary Features (Core Functionality)

#### **1. Single Conversion**
Convert one base currency into another with instant results.

#### **2. Multi-Conversion**
Convert from one base currency into **to three** additional currencies at once.

#### **3. Favourite Currencies**
Choose your three most-used currencies for faster selection across the entire app.

#### **4. Live Exchange Rates**
Synchronize real-time FX rates using **exchangeratesapi.io API** (requires API key).

#### **5. Historical 5-Day Charts**
Track short-term market movements visually with a clean, custom-drawn chart.
- Shows 5-day trend
- Live historical data requires **Professional/Business plan** (API restriction)

#### **6. API Key Integration**
Full integration with exchangeratesapi.io  
- Enter your API key in Settings  
- Enable/disable mock mode  
- Optional toggle for Professional/Business subscription

---

### Secondary Features

- Dark & Light mode  
- Clean UI/UX
- Currency search with flags, names, and ISO codes  
- Intelligent favourite grouping in currency picker  
- Animated bottom-sheet currency selector with grabber  
- Mock mode: synthetic rates for offline or testing scenarios  

---

## Screenshots (placeholders)

> Screenshots here


---

## Installation

### Option A — Install APK (recommended for users)

1. Download the latest `currentcy_v1.0.0.apk` from the **Releases** section.
2. Install the APK.
4. Open the app & start converting currencies.

---

### Option B - Building From Source (Developers)

#### Requirements
- Flutter 3.38
- Android SDK
- Dart

#### Clone & Run
```bash
git clone https://github.com/dariohaefliger/currentcy.git
cd currentcy
flutter pub get
flutter run
```

---

## Adding Your API Key
1. Open the Settings screen.
2. Enter your exchangeratesapi.io API key ande save it.
3. Disable "Use mock rates".
4. (Optional) Enable "Professional / Business plan" toggle if you have such a (exchangerateapi.io) subscription.

## API Requirements & Limitations
### Live Exchange Rates (single and multi conversion)
- Require a valid API key
- Works on all exchangeratesapi.io plans
### Historical Charts
- Only available on
    - Professional Plan
    - Business Plan
- This is a limitation imposed by exchangeratesapi.io, not the app.
- Mock mode still provides synthetic history for demo/testing.

---

## Architecture Overview
Currentcy follows a modular service & repository pattern.
```txt
currentcy/lib/
├── main.dart
├── page
│   ├── charts_history.dart
│   ├── multi_conv.dart
│   └── single_conv.dart
├── services
│   ├── currency_repository.dart
│   └── exchange_rates_service.dart
└── settings
    ├── exchange_rates_info.dart
    ├── settings_main.dart
    ├── settings_manager.dart
    └── theme_manager.dart
```

---
## License
This project is licensed under the PolyForm Noncommercial License 1.0.0.
You may use, modify, and build upon the code **for noncommercial purposes only**.

---
## Authors
**Developed by the Currentcy Team**
- [j0sephcode](https://github.com/j0sephcode)
- [siggilicious](https://github.com/siggilicious)
- [dariohaefliger](https://github.com/dariohaefliger)