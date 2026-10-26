# domain

Plain Dart only. No Flutter imports here, so everything is easy to unit test.

- `models/case_content.dart` - CaseInfo, Scene, Evidence, Suspect, AccusationOption, Solution, ClueLink, and `CaseContent` (the whole case file, with `validate()`)
- `models/player_data.dart` - PlayerProgress, CaseSummary, Note, BoardNode, BoardLink, AccusationRecord, HintRecord, CaseStatus, and `RuleViolation`
- `accusation_checker.dart` - `AccusationChecker.check()` compares an `Accusation` with the `Solution` and returns an `AccusationResult`: solved / not quite / incomplete, how many of the three parts were right (never which), required links drawn, and the score (100, minus 10 per wrong try and 5 per hint, floor 10)
- `hint_engine.dart` - rule-based hint scoring (+4 key clue, +2 unresolved, +1 stage fit, -3 recently shown). Coming next.

Owner: Lakshmi
