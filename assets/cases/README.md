# Case content

Each case is one JSON file. The app loads these into SQLite on first launch, so new cases can be added without code changes: drop a file here and add its path to `CaseLoader.bundledCases`.

- `the_last_toast.json` - Case 1. Three rooms, twelve clues (seven key, five red herrings), five suspects, eight clue links.

## File shape

```
case                 id, title, synopsis, intro, epilogue, difficulty, content_version
scenes[]             id, name, description, order_index
evidence[]           id, scene_id, title, description, kind, is_key
suspects[]           id, name, role, bio, statement, motive_hint
accusation_options   methods[] and motives[] of {id, label}
solution             culprit_id, method_id, motive_id, required_links[]
clue_links[]         id, evidence_a_id, evidence_b_id, description, stage (1-3)
```

Bump `content_version` whenever the story text changes so existing installs pick up the update.
