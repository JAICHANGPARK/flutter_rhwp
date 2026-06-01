# 2026-06-02 native editor word delete boundaries

## 작업한 내용

- Flutter-native editor의 Ctrl/Alt+Backspace, Ctrl/Alt+Delete 단어 삭제가 본문 문단 경계를 넘도록 변경했다.
- 기존 단어 이동 계산인 `_wordPositionFrom`을 단어 삭제에도 재사용하고, 계산된 cursor 범위를 `RhwpSelectionRange`로 바꿔 `_deleteSelectedText`에 맡기도록 정리했다.
- 같은 문단은 기존처럼 `deleteText`로 처리하고, 문단을 넘는 범위는 rhwp core의 `deleteRange` command로 처리한다.
- 첫 문단 끝에서 다음 문단 시작으로 forward delete, 두 번째 문단 시작에서 이전 단어 시작으로 backward delete 되는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView fallback 없이 실제 편집기로 쓰이려면 단어 단위 삭제도 문서 구조를 따라야 한다. 이전 구현은 현재 문단의 문자열 안에서만 offset/count를 계산했기 때문에 문단 시작이나 끝에서는 Ctrl/Alt+Backspace, Ctrl/Alt+Delete가 자연스럽게 동작하지 않았다.

이번 변경은 단어 이동과 단어 삭제가 같은 위치 계산을 공유하게 만든다. 그래서 앞으로 빈 문단, 페이지 경계, selection 확장 같은 경계 조건을 한 곳에서 개선할 수 있다.

## 이 작업을 통해 배울점

- 단어 삭제는 단순 문자열 삭제가 아니라 "현재 caret에서 다음 word boundary까지의 selection 삭제"로 모델링하는 편이 문단 경계에 강하다.
- 같은 문단 삭제와 multi-paragraph 삭제를 같은 selection 삭제 함수로 모으면 command editor의 동작 차이를 줄일 수 있다.
- Flutter-native editor는 upstream Web editor와 같은 UX를 만들기 위해 작은 키보드 편집 경계 조건을 계속 줄여가야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor deletes by word across paragraph boundaries"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor deletes by word with keyboard modifiers"`
- `flutter analyze`
- `git diff --check`
