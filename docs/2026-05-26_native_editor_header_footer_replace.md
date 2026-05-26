# 2026-05-26 Native Editor Header Footer Replace

## 작업한 내용

- rhwp Rust 코어의 `delete_text_in_header_footer_native`를 `deleteTextInHeaderFooter` FRB command로 노출했다.
- Dart 공개 API에 `RhwpCommand.deleteTextInHeaderFooter()`와 `RhwpDocument.deleteTextInHeaderFooter()`를 추가했다.
- Flutter-native editor의 머리말/꼬리말 텍스트 다이얼로그가 기존 텍스트를 조회해 미리 채우도록 변경했다.
- 저장 시 `Replace existing text`가 켜져 있으면 기존 머리말/꼬리말 텍스트를 삭제한 뒤 새 텍스트를 삽입한다.
- 신규 머리말/꼬리말은 기존처럼 없으면 생성 후 텍스트를 넣는다.
- Dart command/API 테스트, Flutter widget 테스트, Rust facade 테스트, changelog를 갱신했다.

## 이 작업을 진행한 이유

이전 단계에서는 머리말/꼬리말에 텍스트를 추가할 수 있었지만, 실제 편집기 관점에서는 기존 내용을 불러와 수정하고 저장하는 흐름이 필요하다. Flutter-native editor가 WebView 없이 실사용 가능한 편집 surface가 되려면 append command보다 replace/edit 흐름이 먼저 갖춰져야 한다.

## 이 작업을 통해 배울 점

- header/footer는 본문 caret과 다른 저장 위치를 가지므로 편집 대상 조회, 삭제, 삽입 command를 명확히 분리해야 한다.
- 기존 값 prefill은 Flutter UI에서 처리하고, 실제 문서 변경은 Rust core command 조합으로 유지하는 것이 WebView 의존을 줄이는 안정적인 포팅 방식이다.
- replace 동작은 현재 단일 header/footer paragraph 기준으로 검증했다. 다중 paragraph header/footer 편집은 별도 split/merge command 연결이 필요하다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor page ribbon replaces header text"`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
- `flutter analyze`
