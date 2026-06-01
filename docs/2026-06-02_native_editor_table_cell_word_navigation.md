# 2026-06-02 native editor table cell word navigation

## 작업한 내용

- Flutter-native editor에서 표 셀 텍스트 편집 중 Ctrl/Alt+Left, Ctrl/Alt+Right가 본문 cursor가 아니라 active table-cell paragraph offset을 이동하도록 변경했다.
- 표 셀 단어 삭제에서 추가한 `_tableCellWordPositionFrom` 계산을 단어 이동에도 재사용했다.
- 같은 셀 문단 안에서는 단어 경계로 이동하고, 셀 문단 끝/시작에서는 다음/이전 셀 문단의 단어 위치로 이동한다.
- 표 셀 선택 상태에서 word navigation이 body cursor 이동으로 새지 않도록 key handling 순서를 조정했다.
- 표 셀 단어 이동 위젯 테스트를 추가하고, 표 셀 단어 삭제 테스트로 회귀를 확인했다.

## 이 작업을 진행한 이유

표 셀 단어 삭제는 구현됐지만, 표 셀 편집 중 Ctrl/Alt+Arrow는 여전히 본문 cursor 이동 경로로 떨어질 수 있었다. 이 상태에서는 표 셀 안에서 단어 단위로 이동한 뒤 바로 삭제하거나 입력하는 자연스러운 편집 흐름이 깨진다.

Flutter-native editor가 WebView fallback 없이 쓰이려면 본문과 표 셀 편집 모드의 키보드 동작이 같은 규칙을 가져야 한다. 이번 작업은 표 셀 내부 word navigation을 active cell selection 모델 위로 올려 그 격차를 줄인다.

## 이 작업을 통해 배울점

- 표 셀 편집 모드는 body cursor와 별도 상태를 쓰므로 key handling에서 먼저 분기해야 한다.
- word boundary 계산은 본문/표 셀 모두에 재사용할 수 있지만, 위치 모델은 각각 `RhwpCursorPosition`과 `RhwpTableCellSelection`으로 분리해야 한다.
- 단어 삭제와 단어 이동이 같은 target 계산을 공유하면 경계 조건을 한 번에 맞출 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves table cell cursor by word with keyboard modifiers"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor deletes table cell words with keyboard modifiers"`
- `flutter analyze`
- `git diff --check`
