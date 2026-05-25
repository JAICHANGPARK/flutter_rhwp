# 2026-05-26 native editor shift click selection

## 작업한 내용

- `RhwpNativeEditor` page overlay에서 Shift+primary click을 감지한다.
- 클릭한 위치를 page layer tree text hit-test로 source cursor position으로 변환한다.
- 현재 selection anchor에서 클릭한 cursor까지 `RhwpSelectionRange`를 확장한다.
- Shift+click은 double/triple-click sequence와 섞이지 않도록 click count 상태를 초기화한다.

## 이 작업을 진행한 이유

Flutter-native 에디터가 WebView 기반 에디터를 대체하려면 키보드 Shift+Arrow뿐 아니라 마우스 기반 selection 확장도 필요하다. 사용자는 caret을 둔 뒤 Shift+클릭으로 범위를 빠르게 지정하고, 그 범위에 복사/잘라내기/서식/삭제를 적용하는 흐름을 기대한다.

## 이 작업을 통해 배울 점

- selection 확장 같은 UX는 문서를 수정하지 않으므로 Rust edit command를 호출하지 않고 controller state만 바꾸는 것이 맞다.
- pointer click sequence와 modifier key handling은 같은 overlay에서 처리하되, Shift+click은 multi-click 선택과 별도 경로로 분리해야 한다.
- Flutter-native editor의 마우스 UX는 page layer tree의 source position을 기준으로 구현해야 zoom과 SVG 렌더링 상태에 덜 의존한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor extends selection with shift click"`
