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

## Features and architecture

FinPilotAI currently provides a five-tab local finance experience: Home, Money, Analysis, Advisor, and Settings. Implemented flows include local profile entry, accounts, transactions, integer-paise budgeting and analysis, recurring bills, supported-platform local reminders, receipt OCR review on supported mobile platforms, deterministic Advisor responses, JSON export, and confirmed local-data deletion.

The code is organized by feature under `lib/features`, with shared app setup and routing in `lib/app`, persistent models and repositories in `lib/data`, and calculations/recurrence rules in `lib/domain`. `FinanceController` coordinates app state and repositories. Existing unit, widget, and data tests are under `test/`.

## Windows setup and commands

The project uses Flutter and Dart from the Flutter SDK. In the current development environment the SDK is at `D:\Development\flutter`; if it is not already on `PATH`, use:

```powershell
$env:Path = "D:\Development\flutter\bin;$env:Path"
flutter --version
dart --version
flutter pub get
```

Start the browser preview from the project root:

```powershell
cd D:\Development\finpilot_new
flutter run -d chrome
```

Run formatter, static analysis, and tests:

```powershell
dart format lib test
flutter analyze
flutter test
flutter build web --release
```

The web build uses SQLite persisted in browser IndexedDB through `sqflite_common_ffi_web`. Browser storage belongs to that origin/profile and is not a cloud backup. Receipt OCR and scheduled bill notifications are unavailable in the browser preview; the UI reports those limitations.

## Platform builds and release preparation

- **Web:** Flutter web toolchain; `flutter build web --release` builds the preview. This does not verify native behavior.
- **Android:** Install Android Studio or the Android command-line tools, Android SDK platform/build tools, and a compatible JDK; configure SDK paths and accept Android SDK licenses before `flutter doctor` and `flutter build apk --debug`. An Android SDK/device was not available in the audited environment. The current Gradle release build uses the debug signing key and is not suitable for distribution. Configure a user-managed release keystore and secret-safe signing properties before any release build. Do not commit signing secrets.
- **iOS:** Requires macOS, Xcode, Apple signing configuration, and a supported iOS device/simulator. Windows cannot run the Xcode build. Current deployment target is iOS 15.0. The iOS bundle identifier (`com.finpilotai.finpilotAi`) and Android application ID (`com.finpilotai.finpilot_ai`) differ; choose and reserve the desired production identifiers before store setup, provisioning, or release.
- **Windows/Linux/macOS:** Flutter desktop tooling plus each platform's native build prerequisites are required. Local reminders are implemented only for Android/iOS; OCR is implemented only for Android/iOS.

Android 13+ notification permission and iOS notification permission are requested only when the user enables reminders. Android schedules inexact reminders and does not request exact-alarm access. iOS usage descriptions for camera/photo selection are in `ios/Runner/Info.plist`. Physical-device verification is still needed for actual permission dialogs, notification delivery/rescheduling, camera/gallery behavior, and OCR.

## Current limitations and planned work

Local profile entry is a convenience session, not secure authentication; it has no password, server verification, app lock, or database encryption. The database and browser storage are local but are not encrypted by this application. Deletion is not a forensic secure erase and cannot remove exports or independent backups. The Advisor is deterministic and local; there is no integrated or verified LLM. OCR uses on-device ML Kit on supported mobile platforms and is heuristic; verify extracted fields before saving. No bank integration, cloud sync, remote push, biometric lock, database encryption, or AI model inference is implemented.

Release work still includes selecting a consistent production app identifier, configuring Android release signing, completing native builds and device testing, and reviewing store-specific privacy and distribution requirements. No signed distributable or store release is produced by these commands.
