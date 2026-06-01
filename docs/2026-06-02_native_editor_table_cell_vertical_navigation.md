# 2026-06-02 native editor table cell vertical navigation

## 작업한 내용

- Flutter-native editor에서 표 셀 텍스트 편집 중 plain Up/Down이 rectangular cell selection 이동이 아니라 active table-cell text caret을 이동하도록 변경했다.
- page layer tree의 table-cell text run geometry를 우선 사용해 같은 셀의 위/아래 텍스트 런으로 이동한다.
- 보이는 target run이 없으면 rhwp core의 `getCellParagraphCount`와 `getCellParagraphLength` fallback으로 이전/다음 셀 문단 offset을 계산한다.
- 표 셀 텍스트 편집 중 Up/Down 위젯 테스트를 추가하고, 기존 표 셀 선택 이동 테스트로 선택 모드 회귀를 확인했다.

## 이 작업을 진행한 이유

표 셀 텍스트 편집 모드에서는 방향키가 셀 자체가 아니라 셀 안의 caret을 움직여야 한다. Left/Right, word navigation, Home/End는 이미 active cell offset 중심으로 동작하지만 Up/Down은 아직 셀 선택 이동 경로로 빠질 수 있었다.

Flutter-native editor가 WebView fallback 없이 실제 편집기로 성장하려면 표 셀 선택 모드와 표 셀 텍스트 편집 모드의 키보드 의미를 분리해야 한다. 이번 작업은 그 분리를 세로 이동에도 적용했다.

## 이 작업을 통해 배울점

- 세로 caret 이동은 단순 paragraph index만으로 처리하면 실제 렌더 위치와 어긋날 수 있으므로, 가능한 경우 page layer geometry를 먼저 사용해야 한다.
- 빈 셀 문단이나 아직 보이지 않는 text run은 layer tree만으로 처리할 수 없어서 core metric fallback이 필요하다.
- 같은 방향키라도 표 셀 선택 모드와 텍스트 편집 모드의 의미가 다르므로 key handling에서 상태 분기가 먼저 이뤄져야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves table cell cursor vertically with arrow keys"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves selected table cells with keyboard"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves table cell cursor with arrow keys"`
- `flutter analyze`
- `git diff --check`
