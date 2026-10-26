# domain

Plain Dart only. No Flutter imports here, so everything is easy to unit test.

- `models/case_content.dart` - CaseInfo, Scene, Evidence, Suspect, AccusationOption, Solution, ClueLink, and `CaseContent` (the whole case file, with `validate()`)
- `models/player_data.dart` - PlayerProgress, CaseSummary, Note, BoardNode, BoardLink, AccusationRecord, HintRecord, CaseStatus, and `RuleViolation`
- `accusation_checker.dart` - `AccusationChecker.check()` compares an `Accusation` with the `Solution` and returns an `AccusationResult`: solved / not quite / incomplete, how many of the three parts were right (never which), required links drawn, and the score (100, minus 10 per wrong try and 5 per hint, floor 10)
- `hint_engine.dart` - Smart Hints. `HintEngine.next(HintState)` builds every possible hint (search a room, pin a clue, compare two clues, make the accusation), scores each with the four rules from section 7 (+4 key clue, +2 unresolved, +1 stage fit, -3 shown recently), and returns the best with a `whyLines` explanation. Ties break accuse, link, pin, find, then by id, so the same state always gives the same hint. Hints never name the culprit, method or motive.

Owner: Lakshmi
