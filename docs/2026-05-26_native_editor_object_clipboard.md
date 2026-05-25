# 2026-05-26 native editor object clipboard

## 작업한 내용

- `copyObjectControl`, `clipboardHasObjectControl`, `pasteObjectControl` command를 Dart API와 Rust facade에 추가했다.
- Flutter-native editor에서 선택된 객체를 Ctrl/Cmd+C, Ctrl/Cmd+X, Ctrl/Cmd+V로 복사, 잘라내기, 붙여넣기 할 수 있게 했다.
- 객체 선택 문맥 메뉴에 잘라내기, 복사, 붙여넣기를 추가했다.
- 객체 붙여넣기는 rhwp core의 내부 control clipboard를 사용하고, 붙여넣기 후에는 새 객체 문단 위치로 cursor를 이동한다.
- Dart command serialization, widget shortcut flow, Rust facade round-trip 테스트를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor를 WebView fallback 없이 실제 편집기로 키우려면 텍스트뿐 아니라 HWP의 핵심 편집 단위인 표, 그림, 도형 같은 control 객체도 기본 clipboard 흐름을 가져야 한다. upstream rhwp core에는 이미 control clipboard API가 있으므로, JS/WebView를 거치지 않고 FRB command surface로 노출하는 것이 가장 직접적인 경로다.

## 이 작업을 통해 배울점

- Flutter-native editor의 clipboard는 텍스트와 객체 도메인을 구분해야 한다. 객체 copy는 OS plain text clipboard가 아니라 rhwp 내부 control clipboard를 사용한다.
- 객체 선택 overlay는 화면 상태이고, 실제 붙여넣기는 section/paragraph/control index를 Rust command target으로 바꾸는 작은 계약으로 처리된다.
- WebView 에디터와 동등해지는 과정은 UI를 한 번에 옮기는 작업이 아니라, core에 있는 편집 primitive를 Flutter interaction에 하나씩 연결하는 작업이다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor copies and pastes selected object controls"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor cuts selected object controls"`
- `cargo test --manifest-path rust/Cargo.toml applies_object_clipboard_commands`
