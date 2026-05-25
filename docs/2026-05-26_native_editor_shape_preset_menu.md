# 2026-05-26 native editor shape preset menu

## 작업한 내용

- Flutter-native editor의 단일 rectangle 삽입 버튼을 shape preset 메뉴로 확장했다.
- 입력 리본에서 rectangle, ellipse, line, text box를 선택해 삽입할 수 있게 했다.
- 각 preset은 rhwp core의 `create_shape_control_native`가 이해하는 `shapeType`, 크기, wrap/treat-as-char 기본값을 사용한다.
- Dart command serialization, Flutter widget flow, Rust facade 테스트를 preset 범위에 맞게 확장했다.

## 이 작업을 진행한 이유

upstream web editor는 브라우저 UI에서 도형 입력을 제공한다. Flutter-native editor가 WebView fallback을 보조하는 수준을 넘어 실제 편집 surface가 되려면 rectangle 하나가 아니라 기본 도형군을 메뉴로 선택할 수 있어야 한다.

이번 작업은 새로운 렌더링 엔진을 만들지 않고, 기존 Rust core shape command를 Flutter ribbon UI에 연결하는 방향을 유지한다.

## 이 작업을 통해 배울 점

- Flutter-native editor의 입력 기능은 WebView/JS 호출이 아니라 Rust command surface를 넓히는 방식으로 확장하는 것이 맞다.
- 도형 삽입은 shape type마다 기본 크기, text wrap, treat-as-char 기본값이 다르므로 UI preset 계층이 필요하다.
- preset 메뉴를 두면 polygon, arc, connector 같은 추가 shape도 같은 구조로 늘릴 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor insert ribbon inserts shape presets"`
- `flutter test test/flutter_rhwp_test.dart`
- `cargo test --manifest-path rust/Cargo.toml applies_insert_shape_command`
- `flutter analyze`
