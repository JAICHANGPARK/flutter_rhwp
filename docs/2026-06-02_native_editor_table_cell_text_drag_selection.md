# 2026-06-02 native editor table cell text drag selection

## 작업한 내용

- Flutter-native editor에서 표 셀 내부 텍스트를 드래그하면 셀 사각형 범위가 아니라 셀 내부 텍스트 범위가 선택되도록 했다.
- 표 셀 text hit에서 시작한 드래그는 별도의 table-cell text drag anchor를 잡고, 같은 셀의 page-layer text hit로 이동할 때 `RhwpTableCellSelection` text range를 갱신한다.
- 기존 표 셀 사각형 드래그 선택은 텍스트가 아닌 셀 영역에서 시작할 때 유지되도록 분리했다.

## 이 작업을 진행한 이유

기존 구현은 표 셀 안의 텍스트에서 드래그를 시작해도 `_tableDragAnchor`가 잡혀 셀 사각형 선택으로 바뀌었다. upstream 웹 에디터의 text selection UX처럼 실제 텍스트 위에서 시작한 드래그는 글자 범위를 선택해야 복사, 삭제, 붙여넣기 같은 후속 편집 명령이 자연스럽다.

Flutter-native editor가 WebView 없이 에디터로 쓰이려면 클릭, 더블클릭, 트리플클릭뿐 아니라 드래그 선택도 현재 편집 컨텍스트를 따라야 한다.

## 이 작업을 통해 배울점

- 표 셀 선택에는 셀 사각형 선택과 셀 내부 텍스트 선택이 공존하므로, pointer down 시점의 hit 대상에 따라 drag anchor를 분리해야 한다.
- page-layer text hit-test를 재사용하면 WebView/DOM 없이도 표 셀 내부 selection range를 Flutter 상태로 유지할 수 있다.
- 기존 셀 범위 드래그 회귀를 막으려면 텍스트 drag와 셀 drag를 별도 테스트로 같이 검증해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text to select a range"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "drags table cells"`
- `flutter analyze`
- `git diff --check`
