# 2026-05-26 native editor table cell shift click selection

## 작업한 내용

- `RhwpNativeEditor`의 rendered table cell overlay에서 Shift+click을 감지한다.
- 기존 `RhwpTableCellSelection`과 클릭한 `RhwpTableCellLayout`을 합쳐 rectangular table cell range를 만든다.
- 기존 active cell index와 cell text offset은 유지해서 이후 text input, merge/split, keyboard navigation이 같은 table selection context를 계속 사용하게 했다.
- widget test로 첫 번째 셀 클릭 후 Shift+클릭이 multi-cell range selection으로 확장되고 Rust edit command를 만들지 않는지 검증했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView 기반 에디터를 대체하려면 표 편집 UX도 마우스로 빠르게 범위를 지정할 수 있어야 한다. 이미 drag selection과 Shift+Arrow range extension은 있었지만, 실제 문서 편집기에서는 Shift+click으로 선택 범위를 확장하는 흐름도 자연스럽게 기대된다.

## 이 작업을 통해 배울 점

- 표 셀 selection은 body text selection과 별도 domain이므로 Shift+click도 table cell hit-test 경로에서 먼저 처리해야 한다.
- selection 확장은 문서를 수정하지 않으므로 undo history나 Rust command surface를 건드리지 않고 controller state만 갱신하는 것이 맞다.
- active cell context를 유지해야 selection range 확장 후에도 셀 내부 입력과 table ribbon action의 대상이 흔들리지 않는다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor extends selected table cells with shift click"`
