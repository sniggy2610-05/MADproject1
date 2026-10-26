# domain

Plain Dart only. No Flutter imports here, so everything is easy to unit test.

- `models/case_content.dart` - CaseInfo, Scene, Evidence, Suspect, AccusationOption, Solution, ClueLink, and `CaseContent` (the whole case file, with `validate()`)
- `accusation_checker.dart` - compares the player's accusation with the solution. Coming next.
- `hint_engine.dart` - rule-based hint scoring (+4 key clue, +2 unresolved, +1 stage fit, -3 recently shown). Coming next.

Owner: Lakshmi
