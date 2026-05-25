# 2026-05-26 native editor rectangle shape insert

## 작업한 내용

- Rust command surface에 `insertShape`를 추가하고 vendored rhwp의 `create_shape_control_native`로 연결했다.
- Dart `RhwpDocument.insertShape()`와 `RhwpCommand.insertShape()`를 추가했다.
- Flutter-native editor 입력 리본에 `Insert rectangle` 버튼을 추가했다.
- 버튼 클릭 시 현재 커서 위치에 사각형 shape control을 삽입하고 커서를 control 뒤로 이동하도록 했다.
- Dart API, Flutter widget, Rust facade 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream web editor는 도형 삽입을 포함한 입력 리본을 제공한다. Flutter-native editor가 WebView fallback에만 기대지 않으려면 텍스트와 표뿐 아니라 그림/도형 같은 HWP control 삽입 기능도 FRB command로 직접 다룰 수 있어야 한다.

이번 작업은 가장 기본 도형인 rectangle을 먼저 native widget 경로에 붙인 것이다. 이후 ellipse, line, textbox, connector, polygon도 같은 command surface 위에서 확장할 수 있다.

## 이 작업을 통해 배울 점

- Flutter-native editor는 JS/WebView를 호출하지 않고 Rust rhwp core의 native command를 직접 노출하는 방식이 유지보수에 유리하다.
- HWP control은 일반 텍스트와 달리 삽입 후 문단 내 control 길이와 cursor 이동 규칙을 별도로 고려해야 한다.
- shape insertion은 객체 선택, drag/resize, z-order, properties 같은 기존 native object editing 기능과 이어지는 기반 기능이다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor insert ribbon inserts a rectangle shape"`
- `cargo test --manifest-path rust/Cargo.toml applies_insert_shape_command`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
- `flutter analyze`
