# 2026-05-26 native editor table cell style

## 작업한 내용

- Rust core에 `apply_table_cell_style_native`를 추가해 표 셀 자체의 `border_fill_id`를 갱신할 수 있게 했다.
- 기존 셀의 BorderFill을 기준으로 필요한 배경/테두리 속성만 덮어써서, 배경색 적용이 기존 테두리를 지우지 않도록 했다.
- Dart command/API에 `applyTableCellStyle`을 추가했다.
- `RhwpNativeEditor` 표 리본에 선택 셀 배경색 swatch, 배경 제거, 기본 테두리 버튼을 연결했다.
- Dart command, document API, Flutter widget, Rust facade 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream rhwp 웹 에디터 수준으로 가려면 표 셀 선택 후 셀 배경과 테두리를 바로 바꿀 수 있어야 한다. 기존 Flutter-native editor는 셀 내부 문단/글자 서식은 바꿀 수 있었지만, 셀 자체 스타일인 `border_fill_id`를 수정하는 경로가 없었다.

표 셀 배경은 문단 배경과 다르게 셀 사각형 전체 렌더링에 영향을 준다. 따라서 paragraph format을 우회해서 처리하면 HWP 문서 구조와 렌더링 의미가 맞지 않는다. 이번 작업은 rhwp core의 표 셀 모델에 맞춰 셀 스타일을 별도 명령으로 분리했다.

## 이 작업을 통해 배울 점

- HWP 표 셀 배경/테두리는 셀의 `border_fill_id`가 가리키는 DocInfo BorderFill로 표현된다.
- 셀 스타일 변경은 기존 BorderFill을 복제해 필요한 속성만 바꾸고 재사용/신규 등록하는 방식이 안전하다.
- Flutter-native editor는 page layer tree의 `modelCellIndex`를 command target으로 사용하면 렌더된 셀 선택과 Rust 문서 모델을 안정적으로 연결할 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart --plain-name "RhwpCommand serializes editing commands"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies table cell fill and border"`
- `cargo test -p flutter_rhwp --lib`
