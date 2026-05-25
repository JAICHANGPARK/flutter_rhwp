# 2026-05-26 native editor table cell vertical alignment

## 작업한 내용

- `applyTableCellStyle` command에 `verticalAlign` 속성을 추가했다.
- Rust core의 표 셀 스타일 적용 경로에서 `verticalAlign` 값을 받아 셀의 `VerticalAlign` 모델 값을 갱신하도록 했다.
- `RhwpNativeEditor` 표 리본에 선택 셀 세로 위/가운데/아래 정렬 버튼을 추가했다.
- Dart command/API, Rust facade, Flutter widget 테스트에 세로 정렬 적용 경로를 추가했다.

## 이 작업을 진행한 이유

HWP 표 편집에서는 셀 배경과 테두리만큼 셀 안쪽 내용의 세로 정렬도 자주 쓰인다. Flutter-native editor가 upstream 웹 에디터 기능을 대체하려면 선택된 표 셀에 대해 내용 위치를 위, 가운데, 아래로 바로 조정할 수 있어야 한다.

이미 rhwp 문서 모델에는 셀별 `vertical_align` 필드가 있고 렌더러도 이 값을 사용한다. 따라서 새 개념을 만들지 않고 기존 셀 스타일 command를 확장해 Flutter UI와 Rust 모델을 연결했다.

## 이 작업을 통해 배울 점

- 표 셀 세로 정렬은 셀 내부 문단 정렬이 아니라 셀 모델의 `vertical_align` 속성이다.
- 같은 셀 스타일 command에 배경/테두리/세로 정렬을 묶으면 Flutter 리본에서 선택 셀 스타일 작업을 일관되게 다룰 수 있다.
- 렌더러가 이미 사용하는 모델 필드를 노출하는 방식이 WebView 없는 native editor 구현에서 가장 유지보수하기 쉽다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies table cell fill and border"`
- `cargo test -p flutter_rhwp --lib applies_commands_exports_and_reopens`
