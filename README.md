# Leave It Here

Leave It Here is a local-first journaling app designed for emotionally heavy days and reflection tracking.

## Current app status

The app is currently functional with:

- A merged Entries experience (create + browse + detail view).
- Breakdown tracking with reflection views (Grid / Calendar).
- Voice logging (record audio and save in entries).
- Manual + heuristic wins support.
- Per-entry permanent lock and app-level lock.
- First-install tutorial with replay from Settings.
- Offline backup export/import for device migration.

## Core features

### Entries

- Add new entries from the Entries page hero card.
- Browse past entries in Grid or List view.
- Open entry details and edit when not permanently locked.
- Voice-only entries are saved with fallback text `[Voice entry]`.

### Entry editor

- Write free-form journal text.
- Mark an entry as a breakdown entry.
- Add wins via callout dialog (supports multiple wins).
- Record a voice note and attach it to the entry.
- Lock forever option is available (new-entry lock-after-save and existing-entry permanent lock).

### Breakdowns

- Log breakdown events and review them in:
	- Grid mode (card-style overview)
	- Calendar mode
- Open a breakdown details view with highlights and edit path (when linked entry is editable).

### Reflection and wins

- Manual wins are always preferred.
- If manual wins are missing, heuristic extraction generates suggested wins from entry text.
- Breakdown highlights are computed over the breakdown window and cached.

### Security

- App lock with PIN.
- Optional biometric unlock.
- Configurable auto-lock timeout.
- Entry-level permanent lock (irreversible from UI).

### Backup & transfer

- Export a local backup file from Settings.
- Share that backup file to your other phone (chat, cloud drive, cable, etc.).
- Import the same backup file on the new device from Settings.
- Entries, breakdowns, settings, reflection cache, and voice notes are restored.
- For safety, app lock is turned off after import on the new device; set PIN again if needed.

### Tutorial and credits

- Tutorial appears on first install.
- Tutorial can be reopened from Settings.
- Credits button opens portfolio URL directly (with clipboard fallback if browser launch fails).

## Architecture and storage

- Local-first persistence: `shared_preferences`
- Notifications: `awesome_notifications`
- Audio recording: `record`
- Audio playback: `just_audio`
- External URL open: `url_launcher`
- File import picker: `file_picker`
- File sharing: `share_plus`
- No backend required.

## Run

```bash
flutter pub get
flutter run --dart-define-from-file=secrets.local.json
```

If you do not use a define file, run with plain `flutter run`.

## Build

```bash
flutter analyze
flutter test
flutter build apk --release
```
