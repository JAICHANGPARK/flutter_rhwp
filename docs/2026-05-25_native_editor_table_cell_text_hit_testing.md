# Native Editor Table Cell Text Hit Testing

## 작업한 내용

- page layer tree의 `stableSourceKey`에 포함된 `/cell:` 경로를 Dart `RhwpLayerTree`가 파싱하도록 했다.
- `RhwpCellTextContext`를 추가해 parent table paragraph, control index, cell index, cell paragraph 정보를 text run에 보관하도록 했다.
- `RhwpTextHitResult`가 cell text context를 함께 반환하도록 확장했다.
- `RhwpNativeEditor`에서 표 셀 내부 텍스트를 탭하면 선택 셀뿐 아니라 active cell offset도 함께 설정하도록 했다.
- 셀 내부 텍스트 tap 후 insert command가 해당 offset으로 나가는 widget test를 추가했다.

## 이 작업을 진행한 이유

이전 단계에서는 선택된 셀에 텍스트를 넣을 수 있었지만, offset은 toolbar의 숫자 입력에 의존했다.
실제 에디터에 가까워지려면 사용자가 셀 안의 텍스트 위치를 직접 탭했을 때 caret 위치가 문서 모델의 cell paragraph offset으로 변환되어야 한다.
rhwp core가 stable source key에 cell path를 이미 제공하고 있으므로, Flutter에서는 그 정보를 해석해 command 대상과 offset을 정확히 잡는 것이 맞다.

## 이 작업을 통해 배울점

- 일반 문단 text run과 셀 내부 text run은 같은 text geometry를 공유하지만, 셀 내부 편집에는 추가로 parent table context와 model cell index가 필요하다.
- stable source key의 기본 `section/para/char`만 파싱하면 셀 내부 command 대상이 부족하므로 `/cell:` suffix를 함께 읽어야 한다.
- 표 셀 hit-test는 cell bounds 선택을 먼저 하고, 그 안에 cell text hit가 있으면 active offset을 보강하는 방식이 자연스럽다.
- 다음 단계는 셀 내부 selection range, 셀 내부 IME composing 위치 표시, cell paragraph 간 이동이다.

## 검증

- `dart format lib/src/rhwp_layer_tree.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `flutter test --plain-name "page layer tree model maps table cell text source context"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor taps table cell text to set cell edit offset"`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
