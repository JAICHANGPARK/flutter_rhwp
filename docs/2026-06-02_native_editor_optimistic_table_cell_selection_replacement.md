# 2026-06-02 Native Editor Optimistic Table Cell Selection Replacement

## 작업한 내용

- Flutter-native editor에서 단일 paragraph table-cell text selection 위에 바로 타이핑하는 경우 Rust `deleteTextInTableCell` command 완료를 기다리지 않고 pending delete mask와 replacement text overlay를 먼저 표시하도록 변경했다.
- 선택 교체 입력 시 화면의 table-cell caret는 replacement text 뒤로 즉시 이동하지만, Rust command 큐에는 원래 table-cell selection context를 보존해서 삭제와 삽입이 올바른 cell paragraph/offset으로 실행되도록 했다.
- 느린 `deleteTextInTableCell` command 중에도 셀 내부 selection mask와 새 글자가 보이고 page SVG refresh/render가 발생하지 않는 widget test를 추가했다.

## 이 작업을 진행한 이유

- body selection replacement는 command 완료 전 optimistic overlay를 쓰게 되었지만, table-cell text selection replacement는 여전히 cell deletion command가 끝난 뒤에야 pending mask와 새 글자가 생길 수 있었다.
- 사용자가 표 셀 안의 선택 텍스트 위에 바로 타이핑할 때 피드백이 늦으면 표 편집이 멈추거나 refresh되는 것처럼 보인다.
- WebView 없이 Flutter-native editor를 실제 편집기로 만들려면 body와 table-cell 선택 교체 모두 같은 즉시 피드백 원칙을 가져야 한다.

## 이 작업을 통해 배울점

- 표 셀 선택 replacement는 `RhwpTableCellSelection`의 원래 selection range와 화면의 optimistic collapsed selection을 분리해야 한다.
- pending delete mask와 pending text overlay는 `RhwpCellTextContext`를 공유해야 body paragraph와 같은 paragraph id를 쓰는 셀 텍스트에서도 정확히 셀 안에 붙는다.
- multi-paragraph cell replacement는 `deleteRangeInTableCell`과 paragraph 재배치가 포함되므로, 이번 작업은 단일 cell paragraph replacement부터 좁게 적용했다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews selected table cell text replacement"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "text input"`
- `flutter analyze`
- `git diff --check`
