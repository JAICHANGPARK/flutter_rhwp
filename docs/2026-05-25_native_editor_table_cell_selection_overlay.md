# Native Editor Table Cell Selection Overlay

## 작업한 내용

- `RhwpTableCellSelection`을 추가해 Flutter-native editor controller가 선택된 표 셀 범위를 상태로 보관하도록 했다.
- 렌더된 표 셀을 탭하면 table edit context 입력값뿐 아니라 controller의 table cell selection도 함께 갱신하도록 했다.
- page overlay가 `RhwpLayerTree.tableCells`와 controller selection을 비교해 선택된 셀을 Flutter 위젯으로 highlight하도록 했다.
- 셀 탭 widget test에서 table cell selection 상태와 overlay 표시까지 검증하도록 확장했다.

## 이 작업을 진행한 이유

표 셀을 탭했을 때 내부 숫자 context만 바뀌면 사용자는 현재 어떤 셀이 선택되었는지 알 수 없다.
Flutter-native editor를 실제 에디터처럼 만들려면 입력 상태와 화면 위 선택 표시가 같은 source of truth를 공유해야 한다.
이번 작업은 표 편집 UX에서 “셀을 선택했다”는 시각 피드백을 추가해 WebView fallback 없이도 편집 흐름이 이어지도록 만든 단계다.

## 이 작업을 통해 배울점

- table selection은 텍스트 selection과 별도 상태로 관리해야 한다. 표 셀 선택과 셀 안 텍스트 caret은 동시에 존재할 수 있기 때문이다.
- overlay는 page 좌표를 위젯 크기로 다시 스케일해 그려야 viewer zoom/layout 변화와 맞는다.
- selection 상태는 row/column range로 들고, 실제 paint bounds는 현재 page layer tree에서 다시 찾아야 rerender 이후에도 유지된다.
- 다음 단계는 drag 기반 multi-cell selection, 선택 셀 border handle, cell property dialog 연결이다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor taps table cell to set table edit context"`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
