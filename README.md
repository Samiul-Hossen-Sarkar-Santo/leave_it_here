# Leave It Here

Leave It Here is a local-first Flutter journaling app focused on emotionally heavy days, reflection, and secure personal logging.

It runs fully offline (no account, no backend required) and supports cross-device migration via local backup export/import.

## Highlights

- Entry writing with Grid/List browsing and full detail view.
- Breakdown tracking with Grid + Calendar reflection views.
- Manual wins + heuristic suggested wins extraction.
- Voice journaling with multiple clips per entry, pause/resume capture, and in-app playback.
- Unsaved changes guard in entry editor before leaving.
- App lock (PIN + optional biometrics) and entry-level permanent lock.
- Offline backup export/import (`.lihbak`) including voice clips.

## Features

### Entries

- Create and browse journal entries from the Entries tab.
- Switch between Grid and List display modes.
- Open entry details to review content and attached voice clips.
- Voice-only logs are supported and saved with fallback text: `[Voice entry]`.

### Entry editor

- Write free-form journal text.
- Mark an entry as a breakdown entry.
- Add multiple wins via callout dialog.
- Record **multiple** voice clips per entry.
- During voice capture:
	- Start recording
	- Pause / Resume recording
	- Stop & Use with save/discard confirmation
	- Capture sheet is protected from accidental outside-tap/drag dismiss
- Play recorded clips immediately inside editor.
- Prompt on back navigation when there are unsaved changes.
- Lock forever support:
	- New entries: lock-after-save toggle
	- Existing entries: explicit “Lock forever” confirmation

### Breakdowns and reflection

- Breakdown records are shown in Grid or Calendar mode.
- Tap a record/day to open breakdown details.
- Breakdown highlights are computed over the breakdown window and cached.
- Linked entry can be edited from breakdown details if not permanently locked.

### Wins extraction

- Manual wins are prioritized.
- If missing, heuristic extraction generates suggested wins from journal text.
- Reflection summary uses entries in the selected breakdown window.

### Security

- PIN-based app lock.
- Optional biometric unlock when available.
- Configurable auto-lock timeout.
- Permanent entry lock to make entries immutable.

### Backup and transfer

- Export writes backup to:
	- `Downloads/LeaveItHere Backups` (preferred)
	- falls back to app-available location when needed
- Backup filename format is timestamped and readable:
	- `leave_it_here_backup_YYYY-MM-DD_HH-mm-ss.lihbak`
- Import flow:
	- In-app backup picker scans known backup directories first
	- Optional fallback to system file picker
- Import restores:
	- entries
	- breakdowns
	- reflection cache
	- settings
	- voice clips
- For device-safety reasons, app lock is disabled after import; user can re-set PIN/biometric on the new device.

### Tutorial and credits

- Tutorial is shown on first launch.
- Tutorial can be reopened from Settings.
- Credits button opens external portfolio URL with clipboard fallback if browser launch fails.

## Tech stack

- Flutter + Material 3
- State management: `ChangeNotifier` (custom controller + `AnimatedBuilder`)
- Local persistence: `shared_preferences`
- Secure secrets/PIN storage: `flutter_secure_storage`
- Biometric auth: `local_auth`
- Hashing: `crypto`
- Notifications: `awesome_notifications`
- Voice recording: `record`
- Voice playback: `just_audio`
- Calendar UI: `table_calendar`
- File paths/storage: `path_provider`
- File picking: `file_picker`
- Sharing: `share_plus`
- External links: `url_launcher`

## Project architecture

- `lib/app/app_root.dart`
	- App bootstrapping, theme wiring, tutorial overlay, lock gate
- `lib/controllers/app_controller.dart`
	- Main state orchestration and app workflows
- `lib/services/*`
	- `storage_service.dart` for local persistence
	- `lock_service.dart` for PIN/biometric logic
	- `voice_entry_service.dart` for audio capture lifecycle
	- `backup_service.dart` for export/import and voice file restoration
	- `extraction_service.dart` for heuristic wins/reflection extraction
- `lib/screens/*`
	- Home, editor, detail, lock, tutorial screens

## Data model notes

- `JournalEntry` supports both legacy single-clip audio fields and current multi-clip fields.
- Backup schema versioning is implemented (`schemaVersion: 1`).
- Existing saved data is loaded with backward-compatible parsing.

## Getting started

### Prerequisites

- Flutter SDK compatible with Dart `^3.10.1`
- Android Studio / Xcode / VS Code tooling for Flutter

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Quality checks

```bash
flutter analyze
flutter test
```

### Build (example)

```bash
flutter build apk --release
```

## Notes

- The app is intentionally local-first and account-free.
- `.lihbak` backup files are app backup containers and are meant to be imported from inside the app.
