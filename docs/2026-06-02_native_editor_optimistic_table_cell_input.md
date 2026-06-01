# 2026-06-02 Native Editor Optimistic Table Cell Input

## 작업한 내용

- Flutter-native editor의 active table-cell text 입력에서 Rust `insertTextInTableCell` command 완료를 기다리지 않고 pending text overlay와 cell caret를 먼저 갱신하도록 변경했다.
- 느린 cell insert command가 진행 중이어도 이어지는 Space/문자 입력은 현재 table-cell caret 위치를 기준으로 overlay에 누적되도록 했다.
- Rust command 큐에는 입력 당시의 table-cell selection context를 보존해서 실제 document 반영 offset이 Flutter optimistic caret와 어긋나지 않도록 했다.
- 느린 table-cell insert command 중 Space 다음 문자 입력이 셀 안에 계속 보이고, page SVG refresh/render가 발생하지 않는 widget test를 추가했다.

## 이 작업을 진행한 이유

- body 입력은 command 완료 전 optimistic overlay를 쓰게 되었지만, 표 셀 입력은 여전히 `insertTextInTableCell` 완료 후에야 overlay가 생길 수 있었다.
- 큰 문서나 복잡한 표에서 command가 늦어지면 사용자는 표 셀 안에서 Space/문자를 입력할 때마다 화면이 멈추거나 refresh되는 것처럼 느낀다.
- WebView fallback 없이 Flutter-native editor를 실제 편집기로 만들려면 body와 table-cell 입력 모두 같은 즉시 피드백 원칙을 가져야 한다.

## 이 작업을 통해 배울점

- 표 셀 입력은 body cursor가 아니라 `RhwpTableCellSelection`과 `RhwpCellTextContext`를 함께 보존해야 optimistic overlay 위치가 맞는다.
- 화면의 optimistic selection과 Rust command에 전달할 원본 selection을 분리해야 빠른 연속 입력의 offset이 안정적으로 유지된다.
- 선택 replacement, overwrite, multi-line 입력은 삭제 mask와 range context까지 함께 다뤄야 하므로 이번 작업은 collapsed table-cell text 입력부터 좁게 적용했다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews rapid table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "rapid text"`
- `flutter analyze`
- `git diff --check`
