# 2026-05-26 Native Editor Header Footer Text

## 작업한 내용

- rhwp Rust 코어의 `get_header_footer_native`와 `insert_text_in_header_footer_native`를 `getHeaderFooter`, `insertTextInHeaderFooter` FRB command로 노출했다.
- Dart 공개 API에 `RhwpHeaderFooterInfo`, `RhwpCommand.getHeaderFooter()`, `RhwpCommand.insertTextInHeaderFooter()`, `RhwpDocument.headerFooter()`, `RhwpDocument.insertTextInHeaderFooter()`를 추가했다.
- Flutter-native editor의 쪽 리본에 머리말/꼬리말 텍스트 삽입 버튼과 입력 다이얼로그를 추가했다.
- 다이얼로그는 적용 범위(양쪽/짝수/홀수), 머리말/꼬리말 내부 문단, offset, 텍스트를 입력받는다.
- Flutter UI는 대상 머리말/꼬리말이 없으면 생성한 뒤 텍스트를 삽입하고, 이미 있으면 바로 텍스트를 삽입한다.
- Dart command/API 테스트, Flutter widget 테스트, Rust facade 테스트, changelog를 갱신했다.

## 이 작업을 진행한 이유

기존 Flutter-native editor는 머리말/꼬리말 control 생성까지만 지원했다. 실제 에디터로 가려면 생성 이후 내용 편집이 가능해야 하므로, WebView의 JS editor를 호출하지 않고 Rust core command를 Flutter 리본에 직접 연결했다.

## 이 작업을 통해 배울 점

- upstream web editor 기능을 Flutter로 옮길 때는 DOM 이벤트를 복사하는 방식보다 Rust command를 먼저 노출하고 Flutter UI를 얹는 방식이 더 안정적이다.
- header/footer는 본문 paragraph와 별도 paragraph collection을 갖기 때문에, 본문 caret 모델과 별도 target 정보를 전달해야 한다.
- 생성 command는 이미 존재하면 실패하므로, UI에서 query command로 존재 여부를 먼저 확인하는 흐름이 필요하다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor page ribbon inserts header text"`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
- `flutter analyze`
