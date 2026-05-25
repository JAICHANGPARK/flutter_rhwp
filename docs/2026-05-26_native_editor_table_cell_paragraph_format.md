# 2026-05-26 native editor table cell paragraph format

## 작업한 내용

- Dart command surface에 `applyParaFormatInTableCell`을 추가했다.
- Rust `apply_command` envelope에서 rhwp core의 `apply_para_format_in_cell_native`를 호출하도록 연결했다.
- `RhwpNativeEditor`의 문단 정렬과 문단 모양 적용 경로가 선택된 표 셀 문단에도 동작하도록 했다.
- 선택된 표 셀에 text run이 있으면 해당 셀 문단을 대상으로 삼고, 빈 셀은 기본 셀 문단 `0`을 대상으로 삼도록 했다.
- Dart command serialization, document convenience API, Rust facade, Flutter widget alignment 동작을 테스트로 보강했다.

## 이 작업을 진행한 이유

Flutter-native editor가 본문 문단 정렬만 지원하면 표 안의 문서 편집은 실제 HWP 편집기와 다르게 느껴진다. 표 셀 안의 텍스트도 좌/중/우/양쪽 정렬과 문단 모양을 적용할 수 있어야 WebView 에디터 fallback을 단계적으로 줄일 수 있다.

rhwp upstream Web API에는 이미 `applyParaFormatInCell` 경로가 있고, vendored Rust core에도 같은 네이티브 명령이 있다. 따라서 JS/WebView를 거치지 않고 FRB command surface로 노출하는 방식이 가장 직접적이다.

## 이 작업을 통해 배울 점

- 표 셀 문단 서식은 본문 paragraph range와 다른 좌표계인 parent paragraph, table control, cell index, cell paragraph를 사용한다.
- Flutter selection state는 사용자에게는 하나의 선택처럼 보이지만, Rust command에는 셀 문단 단위의 명확한 target list로 변환되어야 한다.
- 빈 셀처럼 page layer text run이 없는 대상도 편집 가능해야 하므로, 셀 layout 정보와 text run context를 함께 사용해야 한다.

## 검증

- `cargo test -p flutter_rhwp --lib applies_commands_exports_and_reopens`
- `flutter test test/flutter_rhwp_test.dart --plain-name "apply para format in table cell command serializes to the Rust command envelope"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies paragraph alignment to table cells"`
