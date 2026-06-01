# 2026-06-02 Native Editor Table Cell Tab Editing

## 작업한 내용

- Flutter-native 에디터에서 표 셀 텍스트 편집 중 `Tab`을 누르면 다음 셀로 이동하면서 텍스트 편집 모드를 유지하도록 변경했다.
- `Shift+Tab`은 이전 셀로 이동하면서 같은 방식으로 텍스트 편집 모드를 유지한다.
- 셀 텍스트 편집 selection 생성 로직을 helper로 분리해 Enter로 셀 편집에 들어가는 경로와 Tab으로 셀을 이동하는 경로가 같은 상태를 만들도록 정리했다.
- 기존 셀 선택 상태의 `Tab` 이동은 셀 선택만 이동하도록 유지하고, 새 테스트로 편집 중 Tab 이동을 검증했다.

## 이 작업을 진행한 이유

- upstream web editor는 표 셀 선택 상태에서 `Tab`/`Shift+Tab`으로 셀 간 이동을 제공한다.
- Flutter-native editor가 WebView 없이 실제 편집기로 쓰이려면, 셀 텍스트를 입력하다가 다음 셀로 자연스럽게 넘어가는 표 편집 흐름이 필요하다.
- 이전 구현은 Tab 이동 후 셀 선택 상태로만 남아 추가 입력을 하려면 다시 Enter/F5가 필요했기 때문에 문서 편집 UX가 끊겼다.

## 이 작업을 통해 배울점

- 표 셀 selection 이동과 표 셀 text editing 이동은 같은 키를 쓰지만 결과 상태가 달라야 한다.
- 이미 텍스트 편집 중인 셀에서 Tab 이동할 때는 `activeCellIndex`, `activeCellParagraph`, `activeOffset`, `isTextEditing`을 명시적으로 구성해야 한다.
- keyboard navigation 테스트는 command payload보다 controller selection 상태가 더 직접적인 검증 지표가 될 수 있다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor tabs between table cells while editing text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves selected table cells with keyboard"`
- `flutter test test/rhwp_widget_test.dart`
