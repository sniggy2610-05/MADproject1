# data

Everything that touches storage.

- `database.dart` - opens SQLite, runs versioned migrations
- `case_loader.dart` - reads bundled JSON from `assets/cases/` into SQLite on first launch
- `repositories/` - one repository per table group (cases, evidence, notes, board, progress, hints)
- `sync/` - Firebase Auth and Firestore backup (SQLite stays the source of truth)

Owner: Lakshmi
