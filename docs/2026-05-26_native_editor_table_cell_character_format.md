# 2026-05-26 native editor table cell character format

## 작업한 내용

- Dart command surface에 `applyCharFormatInTableCell`을 추가했다.
- Rust `apply_command` envelope에서 `apply_char_format_in_cell_native`를 호출하도록 연결했다.
- `RhwpNativeEditor`의 서식 리본이 선택된 표 셀의 text run 전체에 글자 서식을 적용하도록 했다.
- 표 셀 안에서 커서 편집 중인 경우에는 본문 입력과 동일하게 pending character format을 저장하고, 다음 입력 텍스트 범위에 적용하도록 했다.
- 명령 직렬화, 문서 convenience API, Rust facade, Flutter widget 동작을 테스트로 보강했다.

## 이 작업을 진행한 이유

기존 Flutter-native editor는 본문 선택에는 굵게, 기울임, 밑줄, 글자 크기, 색상 같은 글자 서식을 적용할 수 있었지만 표 셀 내부 텍스트에는 같은 경로가 없었다. 실제 HWP 편집기처럼 동작하려면 표 셀도 본문과 같은 편집 단위가 되어야 한다.

upstream rhwp 코어에는 이미 셀 내부 문단 글자 서식 API가 있으므로, WebView나 JS API를 거치지 않고 FRB Rust command surface로 노출하는 것이 구조적으로 맞다.

## 이 작업을 통해 배울 점

- Flutter-native editor에서 표 셀은 본문 paragraph selection과 별도 selection model을 갖기 때문에, 서식 적용도 body range와 table-cell range를 분기해야 한다.
- page layer tree의 cell context는 Flutter overlay뿐 아니라 편집 명령의 대상 범위를 결정하는 데도 사용할 수 있다.
- Web editor 기능을 Flutter로 옮길 때는 UI를 그대로 변환하기보다, Rust core가 이미 가진 command를 Dart API로 노출하고 Flutter selection state와 연결하는 방식이 유지보수에 유리하다.

## 검증

- `cargo test -p flutter_rhwp_rust --lib applies_commands_exports_and_reopens`
- `flutter test test/flutter_rhwp_test.dart --plain-name "table cell commands serialize to Rust envelopes"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies character format to selected table cells"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies pending character format to table input"`
