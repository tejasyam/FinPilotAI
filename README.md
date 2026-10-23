# FinPilotAI

FinPilotAI is a local-first personal finance app built with Flutter. Financial data, transactions, budgets, analysis, and bill reminders use the local database.

## Local data foundation

- SQLite database file: `finpilot_ai.db` in the platform application support directory.
- Schema version 2 stores accounts, transactions, budgets, bills, recurrence anchors, series keys, and local app settings. Migration callbacks are centralized in `lib/data/database/database_migrations.dart`.
- Money is stored and calculated as integer paise. Transaction direction is an explicit `income` or `expense` value.
- Persisted dates use UTC ISO 8601 timestamps. Period calculations use half-open UTC intervals `[start, end)`, so the end is excluded and adjacent periods do not double count records.
- Current balance is the sum of account opening balances plus all recorded income minus all recorded expenses. Net cash flow is income minus expenses only within a selected date interval.
- Data stays on the device. No network service is configured by this milestone.
- Recurring bills advance when an unpaid occurrence is marked paid. Monthly/yearly dates retain the original calendar-day anchor, so a January 31 bill due in February on the 28th returns to the 31st in March. A unique database index prevents duplicate bill occurrences within a series.
- Scheduled bill notifications use `flutter_local_notifications` on Android and iOS. The app asks for permission only after the user enables reminders in Settings. Notifications are scheduled at 9:00 AM local time on the bill due date using inexact Android scheduling; exact-alarm access is not requested. Settings and bill records are saved locally.
- Android includes notification permission and boot-rescheduling manifest entries. On Android 13+, the user must grant notification permission. iOS prompts for alert, sound, and badge permission the first time reminders are enabled; notification permission can later be changed in system Settings.
- Windows and browser previews support bill management and recurrence data, but do not schedule reminders. Browser notifications cannot be scheduled while the browser is closed, so the preview reports this limitation instead of treating browser notifications as scheduled reminders. iOS builds should be made on macOS with Xcode; no cloud or push-notification setup is required.
- Android, iOS, and macOS use the native `sqflite` factory; Windows and Linux use `sqflite_common_ffi`. All native databases are stored in the platform application support directory. Web uses `sqflite_common_ffi_web`, which persists its SQLite virtual filesystem in browser IndexedDB. Its web runtime needs `web/sqlite3.wasm` and `web/sqflite_sw.js`; regenerate them with `dart run sqflite_common_ffi_web:setup` after changing the package version. Browser persistence is experimental and is scoped to the current origin (including its port).

Run `flutter test` to exercise model validation, finance calculations, repositories, migrations, and persistence using isolated local test databases.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
