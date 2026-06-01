# 2026-06-02 native editor table cell arrow navigation

## 작업한 내용

- Flutter-native editor에서 표 셀 텍스트 편집 중 plain Left/Right가 rectangular cell selection 이동이 아니라 active table-cell paragraph offset을 이동하도록 변경했다.
- 같은 셀 문단 안에서는 offset을 1씩 이동하고, 문단 끝/시작에서는 다음/이전 셀 문단으로 넘어가도록 했다.
- 다음 셀 문단 존재 여부는 rhwp core의 `getCellParagraphCount`로 확인하고, 이전 셀 문단 끝 offset은 page layer tree 또는 `getCellParagraphLength` fallback으로 계산한다.
- 표 셀 텍스트 편집 중 Left/Right 위젯 테스트를 추가하고, 기존 표 셀 선택 이동 테스트로 rectangular selection 회귀를 확인했다.

## 이 작업을 진행한 이유

표 셀 word navigation과 Home/End는 active cell offset을 갱신하게 됐지만, 가장 기본인 plain Left/Right가 아직 셀 선택 이동으로 처리될 수 있었다. 텍스트 편집 모드에서는 화살표 키가 셀 자체가 아니라 셀 안의 caret을 움직여야 입력, 삭제, 상태 표시가 일관된다.

Flutter-native editor가 WebView fallback 없이 실제 문서 편집기로 쓰이려면 표 셀 선택 모드와 표 셀 텍스트 편집 모드의 키보드 의미를 분리해야 한다. 이번 작업은 그 분리를 좌우 이동에 적용했다.

## 이 작업을 통해 배울점

- 같은 키라도 표 셀 선택 모드와 텍스트 편집 모드에서는 의미가 다르므로 key handling에서 상태를 먼저 판별해야 한다.
- 셀 문단 경계 이동은 visible layer tree와 Rust core metric fallback을 함께 써야 빈 문단에도 대응할 수 있다.
- 표 셀 caret 이동, word navigation, Home/End가 같은 active selection model을 공유하면 후속 입력/삭제가 안정적이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves table cell cursor with arrow keys"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves selected table cells with keyboard"`
- `flutter analyze`
- `git diff --check`
