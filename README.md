# Midnight Manor

A cozy, offline detective mystery for Android. Explore Blackwood Manor, collect evidence, pin clues to the Evidence Board, connect them with string, and accuse the culprit.

**Team Midnight Minds:** Snigdha Addagarla (UI, Evidence Board, animations) and Lakshmi Mokshagna Annam (data, logic, hints, Firebase).

## Stack

Flutter + Dart, SQLite via `sqflite` (offline source of truth), `provider` for state, `go_router` for navigation, Firebase Auth + Cloud Firestore for optional sign-in and backup.

## Getting started

1. Install Flutter (stable) and the Android SDK, then check with:
   ```
   flutter doctor
   ```
2. Clone the repo and fetch packages:
   ```
   git clone https://github.com/sniggy2610-05/MADproject1.git
   cd MADproject1
   flutter pub get
   ```
3. Run on an emulator or a connected phone:
   ```
   flutter run
   ```
4. Run the tests:
   ```
   flutter test
   ```

Firebase is optional and not configured yet. `google-services.json` and `firebase_options.dart` are git-ignored; each developer adds their own copy after running `flutterfire configure`.

## Project layout

```
lib/
  domain/        plain Dart models, accusation checker, hint engine (no Flutter imports)
  data/          SQLite database, migrations, JSON case loader, repositories, Firebase sync
  state/         Provider view models, one per feature
  presentation/  theme, router, screens, widgets (Evidence Board lives here)
assets/cases/    case content as JSON (Case 1: The Last Toast)
test/            unit and widget tests
docs/
  AI_LOG.md      honest log of every AI tool use
  design/        wireframes, navigation map, animation storyboards
```

## How we work

- **Branches:** one feature branch per task (`feature/...`), merged into `main` through a pull request after review.
- **Kanban:** Backlog, To Do, In Progress, Review, Done. A card is Done only after review and merge.
- **Milestones:** tagged commits at Milestone 1 (UI and navigation) and Milestone 2 (full case playable).
- **No secrets in the repo.** Keystores, Firebase config and key properties are git-ignored.
- **AI log:** every AI-assisted change is recorded in `docs/AI_LOG.md`.

## Sprint plan (14 days)

| Days | Goal |
|------|------|
| 1-4 | Foundation: repo, Kanban, design pack, Flutter project, navigation, theme. **Milestone 1** |
| 5-7 | Static UI with placeholder data, Evidence Board dragging and zoom |
| 8-11 | SQLite, repositories, JSON loader, accusation checker, hint engine, Firebase, animations, tests |
| 12 | **Milestone 2:** full case playable from intro to result |
| 13-14 | Bug fixing, device testing, signed APK, README, UML, demo video, slides |
