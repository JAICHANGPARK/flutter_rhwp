# Native Editor Table Row Column Editing

## 작업한 내용

- `RhwpCommand.insertTableRow`, `insertTableColumn`, `deleteTableRow`, `deleteTableColumn`을 Dart command surface에 추가했다.
- `RhwpDocument`에 같은 이름의 convenience API를 추가했다.
- Rust facade가 table row/column command를 vendored rhwp core의 `insert_table_row_native`, `insert_table_column_native`, `delete_table_row_native`, `delete_table_column_native`로 전달하도록 했다.
- `RhwpNativeEditor` toolbar에 표 문단, 컨트롤, 행, 열 입력과 행/열 추가·삭제 버튼을 추가했다.
- 표 삽입 후 반환되는 `paraIdx`를 table editing context에 저장해 바로 행/열 작업을 이어갈 수 있게 했다.
- Dart command unit test, Flutter widget test, Rust facade test를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView fallback을 대체하는 방향으로 가려면 단순 표 삽입 이후의 표 편집 흐름이 필요하다.
HWP 문서에서는 표의 행/열 추가와 삭제가 기본 편집 작업이므로, 이 기능을 command surface에 먼저 열어두면 이후 셀 선택, 병합, 셀 서식 기능을 같은 경로로 확장할 수 있다.
이미 rhwp core에 구현된 table CRUD 로직이 있으므로 Flutter는 표 편집 context를 수집하고 command intent만 전달하도록 유지했다.

## 이 작업을 통해 배울점

- 표 삽입 위치는 문서 상태에 따라 달라지므로 Rust 반환값의 `paraIdx`를 Flutter editor 상태에 반영해야 후속 table command가 맞는 대상을 찾는다.
- table command는 일반 cursor offset보다 parent paragraph, control index, row, column context가 중요하다.
- 지금은 toolbar 숫자 입력으로 context를 지정하지만, 다음 단계에서는 page layer tree의 table/cell hit-test를 통해 이 값을 자동으로 채우는 것이 자연스럽다.
- 행/열 편집은 body table 기준으로 연결됐다. nested table, 선택 범위 기반 row/column 작업, 셀 병합/분할은 별도 증분으로 다뤄야 한다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "table row and column commands serialize"`
- `flutter test --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toolbar edits table rows and columns"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
