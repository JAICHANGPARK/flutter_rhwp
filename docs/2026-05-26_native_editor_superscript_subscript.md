# 2026-05-26 native editor superscript subscript

## 작업한 내용

- Dart command API의 `applyCharFormat`, `applyCharFormatRange`, `applyCharFormatInTableCell`에 `superscript`와 `subscript` 속성을 추가했다.
- Flutter-native 서식 ribbon에 위첨자/아래첨자 버튼을 추가하고, 두 속성이 동시에 켜지지 않도록 서로 반대 속성을 끄는 command를 같이 보낸다.
- collapsed selection 상태에서 선택한 위첨자/아래첨자가 다음 본문 입력과 표 셀 입력에 pending character format으로 적용되도록 했다.
- 글자 모양 dialog에 위첨자/아래첨자 선택 chip을 추가했다.
- Rust facade 회귀 테스트와 Dart command/widget 테스트에 `superscript`/`subscript` command JSON 검증을 추가했다.

## 이 작업을 진행한 이유

upstream rhwp core는 `parse_char_shape_mods`에서 `superscript`와 `subscript`를 이미 처리한다. HWP 글자 모양에서 위첨자/아래첨자는 기본 서식 기능이므로, WebView fallback이 아닌 Flutter-native editor에서도 선택 텍스트와 다음 입력에 바로 적용되어야 한다.

## 이 작업을 통해 배울 점

- core가 이미 지원하는 character property는 Dart command envelope와 Flutter UI를 확장하는 방식으로 빠르게 노출할 수 있다.
- 위첨자와 아래첨자는 상호 배타적인 서식이므로 UI callback에서 반대 속성을 명시적으로 `false`로 보내야 문서 상태가 모호해지지 않는다.
- 선택 영역 서식과 pending 입력 서식이 같은 merge 경로를 쓰면 toolbar, dialog, 본문 입력, 표 셀 입력의 동작을 일관되게 유지할 수 있다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt --manifest-path rust/Cargo.toml`
- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
- `flutter test test/flutter_rhwp_test.dart`와 `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies inline character toolbar values"`는 현재 샌드박스가 `127.0.0.1` 테스트 소켓 생성을 막아 로딩 단계에서 실행하지 못했다.
