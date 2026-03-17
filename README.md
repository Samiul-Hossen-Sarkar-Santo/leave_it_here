# Leave It Here

Leave It Here is a simple, soothing journaling app focused on one goal: helping her see what she has accomplished, especially after difficult days.

## What it does

- Logs daily journal entries.
- Lets her record breakdown dates.
- Uses a lightweight in-app heuristic highlighter to pull meaningful achievements from journal text.
- Shows accomplishments under each breakdown record so progress is visible over time.
- Lets users edit wins whenever suggestions do not feel right.
- Sends a daily reminder to write an entry.

## Win extraction behavior

- The app runs fully offline using an enriched heuristic extractor.
- Reflection summaries are recomputed only when new entries appear in that breakdown window (or when wins-per-breakdown setting changes).

## Tech details

- Local-first storage with `shared_preferences`.
- Daily local notifications with `awesome_notifications`.
- No backend required.

## Run

```bash
flutter pub get
flutter run
```
