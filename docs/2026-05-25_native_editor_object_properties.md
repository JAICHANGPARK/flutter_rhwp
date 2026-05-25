# 2026-05-25 native editor object properties

## 작업한 내용

- Dart command surface에 `getObjectProperties`와 `setObjectProperties`를 추가했다.
- `RhwpDocument.objectProperties()`와 `RhwpDocument.setObjectProperties()` 편의 API를 추가해 선택 개체의 크기와 위치 값을 읽고 저장할 수 있게 했다.
- Rust facade가 개체 타입에 따라 rhwp core의 shape/picture 속성 API로 라우팅하도록 연결했다.
- `RhwpNativeEditor` edit ribbon과 object context menu에 개체 속성 진입점을 추가했다.
- Flutter-native dialog에서 너비, 높이, 가로 위치, 세로 위치를 수정한 뒤 undo-aware edit flow로 반영하도록 했다.
- command serialization, document convenience API, widget interaction test를 추가했다.

## 이 작업을 진행한 이유

개체를 선택하고 삭제하거나 앞뒤 순서를 바꾸는 기능만으로는 HWP 편집기 경험이 부족하다. 사용자가 그림, 도형, 글상자를 실제 문서 편집 대상으로 다루려면 크기와 위치를 조정할 수 있어야 한다. upstream rhwp core가 제공하는 속성 API를 Flutter/Rust bridge에 연결하면 WebView fallback에만 의존하지 않고 100% Flutter editor track에서도 개체 편집 범위를 넓힐 수 있다.

## 배울점

- Flutter-native editor의 object selection은 화면 overlay 상태에 그치지 않고 section, paragraph, control index를 command target으로 안정적으로 전달해야 한다.
- 읽기성 command인 `getObjectProperties`는 snapshot을 만들 필요가 없지만, 쓰기성 command인 `setObjectProperties`는 undo/redo 이력을 위해 `_runEdit` 경로를 거쳐야 한다.
- shape과 picture는 rhwp core의 내부 API가 다르므로 facade에서 타입별 fallback을 명확히 두는 편이 Dart API를 단순하게 유지한다.

## 검증

- `dart format --set-exit-if-changed lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `flutter test test/flutter_rhwp_test.dart --plain-name "object control commands serialize to Rust envelopes"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor edit ribbon applies selected object properties"`
- `cargo fmt --check`
- `cargo test applies_commands_exports_and_reopens`
- `flutter analyze`
- `flutter test`
- `(cd example && flutter test)`
- `cargo test`
