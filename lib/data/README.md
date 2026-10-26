# data

Everything that touches storage.

- `database.dart` - `AppDatabase`: opens SQLite, creates the schema on first run, and runs versioned migrations on upgrade. Bump `schemaVersion` and add an entry to `_migrations` when the schema changes.
- `case_loader.dart` - `CaseLoader`: reads bundled JSON from `assets/cases/` into the content tables. Only writes when a case is new or its `content_version` is higher, so player data survives story updates.
- `repositories/` - one repository per table group (cases, evidence, notes, board, progress, hints). Coming next.
- `sync/` - Firebase Auth and Firestore backup (SQLite stays the source of truth). Coming later.

## Tables

Content (read-only during play): `cases`, `scenes`, `evidence`, `suspects`, `accusation_options`, `solutions`, `clue_links`.

Player (written during play): `player_progress`, `evidence_collected`, `notes`, `board_nodes`, `board_links`, `accusations`, `hint_history`.

`accusation_options` is one table beyond the proposal: it holds the method and motive choices the accusation screen shows, so the solution can point at an option id instead of free text.

Owner: Lakshmi
