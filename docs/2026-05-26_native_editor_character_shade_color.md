# 2026-05-26 native editor character shade color

## 작업한 내용

- Dart command API의 `applyCharFormat`, `applyCharFormatRange`, `applyCharFormatInTableCell`에 `shadeColor` 속성을 추가했다.
- Flutter-native 서식 ribbon에 글자 배경색 swatch를 추가하고, 선택 텍스트와 선택 표 셀 텍스트에 적용되도록 연결했다.
- collapsed selection 상태에서 선택한 글자 배경색이 다음 본문 입력과 표 셀 입력에 pending character format으로 적용되도록 했다.
- 글자 모양 dialog에 `Text background` 선택 영역을 추가했다.
- Rust facade 회귀 테스트와 Dart command/widget 테스트에 `shadeColor` command JSON 검증을 추가했다.

## 이 작업을 진행한 이유

upstream rhwp core는 글자 모양 속성으로 `shadeColor`를 처리할 수 있지만, Flutter-native editor 표면에서는 텍스트 색상까지만 노출되어 있었다. HWP 편집기에서 글자 배경색은 기본 서식 기능에 가깝기 때문에 WebView fallback 없이도 Flutter-native 경로에서 다룰 수 있어야 한다.

## 이 작업을 통해 배울 점

- FRB 명령 payload가 `properties` JSON을 통과시키는 구조라면 Rust enum을 새로 만들지 않고도 core가 지원하는 서식 속성을 Dart API와 UI로 노출할 수 있다.
- 선택 영역 서식과 collapsed selection pending 서식은 같은 속성 집합을 공유해야 사용자가 toolbar에서 선택한 서식이 다음 입력에도 자연스럽게 이어진다.
- 표 셀 텍스트는 body text와 command가 다르므로, 새 character property를 추가할 때 두 경로를 모두 테스트해야 한다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt --manifest-path rust/Cargo.toml`
- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
- `flutter test test/flutter_rhwp_test.dart`와 `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies inline character toolbar values"`는 현재 샌드박스가 `127.0.0.1` 테스트 소켓 생성을 막아 로딩 단계에서 실행하지 못했다.
