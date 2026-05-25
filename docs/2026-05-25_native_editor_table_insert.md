# Native Editor Table Insert

## 작업한 내용

- `RhwpCommand.insertTable`와 `RhwpDocument.insertTable()`을 Dart API에 추가했다.
- Rust facade가 `insertTable` command를 받아 vendored rhwp core의 `create_table_native`로 전달하도록 했다.
- `RhwpNativeEditor` toolbar에 행/열 입력과 `Insert table` 버튼을 추가했다.
- 선택 영역이 있을 때는 선택 텍스트를 먼저 삭제하고 selection start 위치에 표를 삽입하도록 했다.
- 표 삽입 결과의 `paraIdx`를 읽어 표 아래 빈 문단으로 커서를 이동하도록 했다.
- Dart command unit test, Flutter widget test, Rust facade test를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor를 실제 편집기로 키우려면 텍스트 편집과 서식만으로는 부족하고, HWP 문서에서 자주 쓰는 객체 삽입 기능이 필요하다.
upstream rhwp core에는 이미 표 생성 로직이 있으므로 Flutter 쪽에서는 WebView나 JS editor를 호출하지 않고 Rust bridge command로 노출하는 것이 맞다.
이번 작업은 리본 UI의 `표` 기능을 Flutter-native command flow에 붙이는 첫 단계다.

## 이 작업을 통해 배울점

- 표 삽입은 일반 텍스트 삽입과 달리 결과 paragraph 위치가 문서 상태와 offset에 따라 달라진다.
- Rust command의 반환 JSON을 활용하면 Flutter editor가 삽입 후 커서를 더 자연스러운 위치로 이동할 수 있다.
- Flutter toolbar는 command intent와 기본 파라미터를 제공하고, 실제 HWP 구조 생성은 rhwp core에 위임하는 구조가 유지보수에 유리하다.
- 이번 단계는 body paragraph 기준 표 삽입만 다룬다. 표 셀 내부 삽입, 표 선택, 행/열 추가/삭제, 셀 병합은 별도 command context가 필요하다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "insert table command serializes"`
- `flutter test --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toolbar inserts a table"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
