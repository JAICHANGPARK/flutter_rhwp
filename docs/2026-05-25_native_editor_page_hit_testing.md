# Native Editor Page Hit Testing

## 작업한 내용

- `RhwpLayerTree.textPositionForPoint()`를 추가해 page 좌표를 문서 section/paragraph/offset으로 매핑했다.
- `RhwpTextRunLayout.closestOffsetForPoint()`를 추가해 text run 내부에서 가장 가까운 caret offset을 찾도록 했다.
- `RhwpViewer.ignorePageOverlayPointer` 옵션을 추가해 일반 viewer는 overlay pointer를 막고, native editor는 overlay tap을 받을 수 있게 했다.
- `RhwpNativeEditor` page overlay에 tap handling을 연결해 렌더링된 문서 텍스트를 누르면 caret 위치가 이동하도록 했다.
- 같은 hit-test 경로로 drag selection을 연결해 문서 위 드래그가 `RhwpSelectionRange`를 갱신하도록 했다.
- layer-tree unit test와 widget test로 page hit-test, caret 이동, drag selection 흐름을 검증했다.

## 이 작업을 진행한 이유

기존 native editor는 toolbar의 `Sec`, `Para`, `Offset` 입력값으로만 편집 위치를 지정했다.
이 방식은 command 테스트에는 충분하지만 실제 에디터 UX와는 거리가 있다. Flutter 위젯 기반 에디터로
가려면 사용자가 문서 페이지 위를 클릭하거나 탭했을 때 해당 텍스트 위치로 caret이 이동해야 하고,
드래그했을 때 selection range가 생겨야 한다.

upstream Web editor도 렌더링 결과와 selection/caret layer를 연결해 hit-test를 수행하므로,
Flutter native editor 역시 Rust에서 받은 page layer tree를 기준으로 입력 위치를 계산하는 구조가 맞다.

## 이 작업을 통해 배울점

- Flutter editor overlay는 단순 시각 효과가 아니라 pointer input을 받는 interactive layer가 되어야 한다.
- Viewer와 editor의 요구사항이 다르므로 overlay pointer 정책은 기본값을 안전하게 두고 editor에서만 열어야 한다.
- hit-test는 DOM 좌표가 아니라 rhwp page 좌표와 document source offset을 잇는 변환 계층으로 분리하는 편이 유지보수에 좋다.
- 다음 단계에서는 shift-click 확장, IME 입력, keyboard navigation을 같은 source-position 모델 위에 얹을 수 있다.

## 검증

- `dart format lib/src/rhwp_layer_tree.dart lib/src/rhwp_viewer.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `flutter analyze`
- `flutter test`
- `(cd example && flutter test)`
- `git diff --check`
