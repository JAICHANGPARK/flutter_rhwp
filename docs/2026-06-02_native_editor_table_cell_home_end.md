# 2026-06-02 native editor table cell home end

## 작업한 내용

- Flutter-native editor에서 표 셀 텍스트 편집 중 Home/End가 본문 caret이 아니라 active table-cell paragraph offset을 이동하도록 변경했다.
- Home은 현재 셀 문단 offset `0`으로 이동하고, End는 현재 셀 문단의 끝 offset으로 이동한다.
- page layer tree에 해당 셀 문단 text run이 없으면 rhwp core의 `getCellParagraphLength` command로 끝 offset을 구하도록 fallback을 추가했다.
- 표 셀 Home/End 위젯 테스트를 추가하고, 표 셀 word navigation 테스트로 key handling 회귀를 확인했다.

## 이 작업을 진행한 이유

표 셀 word navigation은 active cell selection 모델로 이동하도록 개선됐지만, Home/End는 여전히 body line navigation 경로로 떨어질 수 있었다. 표 셀 편집 중에는 키보드 이동이 항상 현재 셀 문단의 offset을 바꿔야 입력, 삭제, 상태바 표시가 일관된다.

Flutter-native editor가 WebView fallback 없이 실제 편집기로 쓰이려면 표 셀 내부의 기본 이동 키도 본문과 분리된 셀 텍스트 모델을 따라야 한다. 이번 작업은 표 셀 편집 모드에서 흔한 시작/끝 이동 동작을 안정화한다.

## 이 작업을 통해 배울점

- 표 셀 편집 모드는 body cursor 이동보다 먼저 key handling에서 분기해야 한다.
- page layer tree만으로 끝 offset을 알 수 없는 셀 문단은 Rust core metric fallback이 필요하다.
- 표 셀 입력 UX는 `activeCellParagraph`와 `activeOffset`을 한 source of truth로 계속 유지해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves table cell cursor with home and end"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves table cell cursor by word with keyboard modifiers"`
- `flutter analyze`
- `git diff --check`
