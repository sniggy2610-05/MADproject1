# AI Usage Log

Every use of an AI tool on this project is recorded here, as required by the course.
For each entry: the tool, what we asked, what it produced, whether we used / changed / rejected it, and how we checked it.

| # | Date | Member | Tool | What we asked | What it produced | Used / changed / rejected | How we checked it |
|---|------|--------|------|---------------|------------------|---------------------------|-------------------|
| 1 | 2026-10-25 | Lakshmi | Claude (Claude Code desktop app) | Read our proposal and explain the project, my role, and the git/Flutter workflow step by step | A plain-language walkthrough of the project, my tasks (data and logic), and the order of work | Used as a study guide; no code produced | Compared against the proposal document |
| 2 | 2026-10-25 | Lakshmi | Claude (Claude Code desktop app) | Install Flutter, Android Studio and the Android SDK on my Windows laptop and clone the repo | Installed Flutter 3.47.8, Android SDK 36, a Pixel 7 emulator; cloned the repo | Used | `flutter doctor` passes for Flutter and Android toolchain |
| 3 | 2026-10-25 | Lakshmi | Claude (Claude Code desktop app) | Create the Flutter project skeleton with the packages from the proposal, folder layout, README and this log | `flutter create` output, pubspec with sqflite / provider / go_router / firebase packages, placeholder home screen with the proposal colors, folder READMEs, smoke test | Used after review; placeholder screen is temporary | `flutter analyze`, `flutter test`, and a debug APK build |
| 4 | 2026-10-25 | Lakshmi | Claude (Claude Code desktop app) | Write the Case 1 content JSON for The Last Toast, the SQLite schema with migrations, and a loader from JSON to SQLite | `assets/cases/the_last_toast.json` (story, 3 rooms, 12 clues, 5 suspects, solution, 8 clue links), `lib/domain/models/case_content.dart`, `lib/data/database.dart`, `lib/data/case_loader.dart`, and tests | Used after reading through the story and checking each clue points at the real solution | `flutter analyze`, `flutter test` (content validation, schema constraints, loader, upgrade keeps player data) |
