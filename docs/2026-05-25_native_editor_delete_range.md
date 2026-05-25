# Native Editor Delete Range

## 작업한 내용

- `RhwpCommand.deleteRange`와 `RhwpDocument.deleteRange()`를 Dart API에 추가했다.
- Rust facade가 `deleteRange` JSON command를 받아 rhwp core의 range deletion으로 전달하도록 했다.
- vendored rhwp의 `delete_range_native`가 facade crate에서 호출될 수 있도록 public으로 여는 최소 패치를 적용했다.
- `RhwpNativeEditor`의 selection deletion helper가 같은 section 안의 multi-paragraph selection을 삭제할 수 있게 했다.
- IME text commit, paste, cut, Enter 전 selection 삭제가 같은 helper를 타므로 여러 문단 선택 후 입력으로 대체되는 흐름이 동작하게 했다.
- Dart command unit test, Flutter widget test, Rust facade test를 추가했다.

## 이 작업을 진행한 이유

이전 구현은 selection이 같은 paragraph 안에 있을 때만 삭제할 수 있었다.
여러 문단을 드래그로 선택한 뒤 글자를 입력하거나 붙여넣으면 선택 영역이 지워져야 하는데, 이 동작이 없으면 Flutter-native editor가 실제 문서 편집기처럼 동작하지 않는다.
upstream rhwp core에는 이미 range deletion 로직이 있으므로 Flutter에서 별도 문서 조작을 만들지 않고 Rust command surface로 노출하는 방식이 맞다.

## 이 작업을 통해 배울점

- 선택 영역 삭제는 단일 paragraph 삭제와 multi-paragraph range 삭제를 분리해야 한다.
- 여러 문단 선택을 삭제할 때는 첫 문단의 뒷부분, 중간 문단, 마지막 문단의 앞부분을 정리한 뒤 문단 병합까지 처리해야 하므로 Rust core의 기존 로직을 재사용해야 한다.
- vendored dependency의 private API를 facade에서 써야 할 때는 패치 범위를 최소화하고 문서로 이유를 남겨야 한다.
- section을 넘는 selection, table cell selection, object selection은 별도 domain으로 확장해야 하며 이번 구현은 body text의 same-section range를 대상으로 한다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "delete range command serializes"`
- `flutter test --plain-name "RhwpNativeEditor replaces multi-paragraph selection"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
