# domain

Plain Dart only. No Flutter imports here, so everything is easy to unit test.

- `models/` - Case, Scene, Evidence, Suspect, Solution, ClueLink, Note, BoardNode, BoardLink, Accusation, HintRecord
- `accusation_checker.dart` - compares the player's accusation with the solution
- `hint_engine.dart` - rule-based hint scoring (+4 key clue, +2 unresolved, +1 stage fit, -3 recently shown)

Owner: Lakshmi
