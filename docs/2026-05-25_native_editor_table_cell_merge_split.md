# Native Editor Table Cell Merge Split

## 작업한 내용

- `RhwpCommand.mergeTableCells`와 `RhwpCommand.splitTableCell`을 Dart command surface에 추가했다.
- `RhwpDocument.mergeTableCells()`와 `RhwpDocument.splitTableCell()` convenience API를 추가했다.
- Rust facade가 cell merge/split command를 vendored rhwp core의 `merge_table_cells_native`와 `split_table_cell_native`로 전달하도록 했다.
- `RhwpNativeEditor` toolbar에 merge range용 `EndR`, `EndC` 입력과 `Merge cells`, `Split cell` 버튼을 추가했다.
- 표 삽입 후 기본 cell editing context를 `row=0`, `column=0`, `endRow=1`, `endColumn=1`로 초기화해 2x2 표에서 바로 병합/분할 테스트를 이어갈 수 있게 했다.
- Dart command unit test, Flutter widget test, Rust facade test를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView fallback을 대체하는 방향으로 가려면 표 삽입과 행/열 편집 이후 셀 단위 편집까지 이어져야 한다.
셀 병합과 분할은 HWP 표 편집에서 기본적인 워크플로우이므로 command surface에 먼저 노출해 두는 것이 다음 단계인 셀 선택, 셀 속성, 테두리/배경 편집의 기반이 된다.
이미 rhwp core에 병합/분할 로직이 있으므로 Flutter는 table context와 command intent만 관리하도록 유지했다.

## 이 작업을 통해 배울점

- 셀 병합은 단일 row/column이 아니라 start/end range가 필요하므로 toolbar context도 시작 셀과 끝 셀을 따로 가져야 한다.
- 셀 분할은 병합된 셀의 시작 좌표를 기준으로 동작하므로 merge/split 테스트는 같은 table paragraph와 control index를 공유해야 한다.
- 지금은 숫자 입력 기반 context이지만, 최종 Flutter-native editor에 가까워지려면 page layer tree 또는 table cell bbox hit-test로 이 값을 자동 설정해야 한다.
- nested table과 multi-cell selection UX는 별도 상태 모델이 필요하다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "table cell commands serialize"`
- `flutter test --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toolbar merges and splits table cells"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
