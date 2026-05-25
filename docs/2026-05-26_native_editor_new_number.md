# 2026-05-26 Native Editor New Number

## 작업한 내용

- rhwp Rust 코어의 `insert_new_number_native`를 `insertNewNumber` FRB command로 노출했다.
- Dart 공개 API에 `RhwpCommand.insertNewNumber()`와 `RhwpDocument.insertNewNumber()`를 추가했다.
- Flutter-native editor의 쪽 리본에 `새 번호로 시작` 버튼과 시작 번호 입력 다이얼로그를 추가했다.
- Dart command 직렬화, 문서 convenience API, Flutter widget flow, Rust round-trip 테스트를 추가했다.
- `CHANGELOG.md`에 새 번호 삽입 지원 내용을 반영했다.

## 이 작업을 진행한 이유

WebView 기반 전체 에디터를 유지하더라도 장기 목표는 Flutter 위젯 기반 에디터를 기능 단위로 키우는 것이다. 쪽 번호 제어는 HWP 편집기에서 자주 쓰는 페이지 편집 기능이고, 이미 Rust 코어에 구현되어 있으므로 Flutter UI와 bridge만 붙이면 WebView 의존 없이 사용할 수 있다.

## 이 작업을 통해 배울 점

- upstream 웹 에디터의 기능을 그대로 포팅하기보다, Rust 코어에 있는 command를 하나씩 Flutter 리본과 Dart API에 연결하는 방식이 유지보수에 유리하다.
- Flutter UI는 입력 다이얼로그와 command dispatch만 담당하고, 문서 구조 변경은 Rust core를 source of truth로 유지해야 한다.
- 페이지 관련 command도 HWP 내부에서는 control 삽입으로 처리될 수 있으므로, 커서 이동과 렌더 refresh는 일반 삽입 command와 같은 흐름으로 검증해야 한다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor page ribbon inserts new page number"`
- `cargo test --manifest-path rust/Cargo.toml inserts_page_and_column_break_commands`
- `flutter analyze`
