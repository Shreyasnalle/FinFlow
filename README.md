# FinFlow - Personal Finance Manager

FinFlow is an elegant, full-featured Personal Finance Application built with Flutter. It prioritizes offline capability and user privacy by storing all financial data strictly locally on your device.

## Core Features

- **Dashboard & Analytics:** View your primary account balance and an overview of your recent expenses alongside a beautiful interactive heat map of your daily spends.
- **Transaction Logs:** Add, edit, or delete transactions with categorization to precisely track out-of-pocket expenses and incoming cash flow. 
- **Financial Goals:** Set, track, and incrementally fund long-term savings goals. 
- **Asset Management:** Record the fixed and fluid value of your real-world investments and assets. The combination of your physical assets and liquid transactions provides a robust **Total Net Worth** overview.
- **Recurring Bills & Auto-Logging:** Standardize your monthly fixed expenses. Simply define a recurring bill (like Internet or Rent) and FinFlow will automatically process the transaction via a background task when the cycle approaches.
- **Financial Projections:** Predict future savings trajectories by viewing comprehensive algorithms that calculate projected 12-month balances. 
- **PDF Export:** Easily export your entire catalog containing your account stats, all recorded transactions, and your physical assets into a generated PDF that works across web and mobile configurations seamlessly.
- **Privacy & Security:** Complete biometric unlock controls and standalone localized `Hive` storage means absolute data security.

## Architecture & Technology
- **Framework:** Flutter (Dart)
- **Local Database:** Hive (High-performance NoSQL local storage)
- **UI Architecture:** Provider (State Management paradigm following Clean Architecture principles)
- **Graphs:** `fl_chart` and `flutter_heatmap_calendar`

## Running the App

To run the application locally on your preferred environment:

```bash
flutter pub get
flutter run
```

Since the application leverages Hive for local persistence, all generated dummy transactions during testing will automatically initialize. Simply clear local data from the App Settings or log out to start fresh!
