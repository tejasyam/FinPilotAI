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
- Receipt scanning uses `image_picker` to capture or select a temporary image and Google ML Kit text recognition for on-device OCR on Android/iOS. The picker-managed temporary image is used during scanning; the app does not copy it into persistent finance storage or upload images/OCR text. Temporary-file cleanup is managed by the plugin/platform, and secure deletion is not guaranteed. OCR suggestions are editable and are never saved until the user confirms the review form. The image picker may request camera or photo access when used; iOS usage descriptions are configured in `ios/Runner/Info.plist`. Browser preview is UI-only for receipt scanning because the on-device ML Kit OCR adapter is unavailable on web; Windows/Linux builds also do not expose this feature. OCR extracts suggestions heuristically and may miss or misread merchant, date, or total, so verify them before saving.
- Android receipt OCR requires a device/emulator compatible with Google ML Kit text recognition. iOS receipt OCR requires macOS/Xcode for building and an iOS 15+ target (the current project target is iOS 15). No cloud OCR, API key, upload, or additional native permission declaration is required on Android beyond the picker flow.
- The Advisor is a deterministic, on-device rules provider; there is no LLM installed or running. It receives only a typed summary calculated from the existing finance data and calculator. Chat history is held in memory for the current screen session, can be cleared from the Advisor, and is not stored in SQLite. Prompts, answers, and finance data are not sent to a service or written to logs. Settings explicitly reports that model inference is unavailable and disabled; no model is automatically downloaded.
- Local profile entry is a convenience session, not authentication. Profile display name and optional email, and a session-active flag, are stored in local app settings. No password is collected or stored; opening local data does not verify identity or protect the database. Sign-out ends the current session and returns to entry while preserving financial records. Anyone with access to the device and app data may be able to read the local database.
- Settings → Privacy and data describes local handling, clears the in-memory Advisor conversation, exports a JSON snapshot, or deletes all local data after an explicit confirmation. The version 1 `finpilotai-finance-export` JSON format includes accounts, transactions, budgets, and bills; amounts are integer paise. It omits profile settings, reminder preferences, and database timestamps. `share_plus` hands the file to the platform share UI or browser download fallback; file sharing is unavailable on Linux in this build. Treat exported files as sensitive and manage/delete them separately.
- Delete all local data first cancels scheduled bill notifications, then atomically deletes accounts, transactions, budgets, bills (including recurring occurrences), and all app settings. If cancellation fails, deletion is aborted. Deletion removes the local profile and session settings; it does not securely overwrite database storage, browser storage, backups, or exported files.
- A local LLM remains optional future work. The current Flutter package ecosystem has pluggable runtimes rather than a single portable engine: for example, `flutter_edge_ai` needs a separate inference-engine package and native setup. Its documented `.litertlm` engine is Android arm64 only and requires Android API 30+, while iOS requires an iOS 15 target; other engines have different ABI/platform constraints. A model must also be selected with a compatible license and installed from a bundled or user-approved source. Before enabling model inference, choose the model, engine, distribution/consent flow, and supported-device matrix, then validate native builds on Android and macOS/iOS. The current deterministic fallback works without those downloads and is not represented as an LLM.
- Android includes notification permission and boot-rescheduling manifest entries. On Android 13+, the user must grant notification permission. iOS prompts for alert, sound, and badge permission the first time reminders are enabled; notification permission can later be changed in system Settings.
- A denied notification permission is recorded locally to prevent automatic repeated prompts. After enabling permission in device settings, the user can explicitly select “Try permission again.” Native scheduled reminders are supported only on Android and iOS; browser, Windows, macOS, and Linux previews do not claim native scheduling.
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
