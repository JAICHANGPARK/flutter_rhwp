# Native Editor Table Cell Text Editing

## 작업한 내용

- Dart command surface에 `insertTextInTableCell`과 `deleteTextInTableCell`을 추가했다.
- `RhwpDocument.insertTextInTableCell()`과 `RhwpDocument.deleteTextInTableCell()` convenience API를 추가했다.
- Rust facade가 위 command를 vendored rhwp core의 `insert_text_in_cell_native`와 `delete_text_in_cell_native`로 전달하도록 했다.
- `RhwpTableCellSelection`에 active cell model index를 보관해, 렌더된 셀 선택과 셀 내부 텍스트 편집 command를 연결했다.
- `RhwpNativeEditor`가 선택된 표 셀이 있을 때 toolbar insert, IME text commit, backspace/delete를 일반 문단 대신 active cell command로 보내도록 했다.
- Dart command/document unit test, Flutter widget test, Rust facade test를 추가했다.

## 이 작업을 진행한 이유

표 셀을 선택하고 병합/분할만 하는 것은 구조 편집에 가깝고, 실제 문서 에디터가 되려면 선택된 셀 안에 바로 텍스트를 입력할 수 있어야 한다.
upstream 웹 에디터도 WASM 문서 엔진에 셀 내부 텍스트 명령을 직접 호출하므로, Flutter-native editor 역시 JS를 거치지 않고 FRB command surface로 같은 기능을 노출하는 쪽이 맞다.
이번 작업은 선택된 Flutter 표 셀을 문서 모델의 실제 cell index와 연결해 셀 내부 텍스트 편집을 가능하게 했다.

## 이 작업을 통해 배울점

- 셀 구조 편집은 row/column 좌표만으로 가능하지만, 셀 내부 텍스트 편집은 rhwp model cell index가 필요하다.
- page layer tree의 `modelCellIndex`를 selection 상태에 보관해야 렌더된 셀 선택이 편집 command까지 정확히 이어진다.
- 아직 셀 내부 caret hit-test는 없으므로 선택된 셀의 offset은 toolbar offset 값을 사용한다. 다음 단계에서 cell text run의 `cellContext`를 이용해 셀 내부 caret을 잡아야 한다.
- table selection과 text selection은 같은 화면에 보이지만 command 대상이 다르므로 editor input routing에서 명확히 분기해야 한다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "table cell commands serialize"`
- `flutter test --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts text into selected table cell"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
