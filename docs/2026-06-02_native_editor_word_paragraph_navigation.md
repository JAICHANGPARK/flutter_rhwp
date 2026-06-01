# 2026-06-02 native editor word paragraph navigation

## 작업한 내용

- Flutter-native editor의 Ctrl/Alt+Left, Ctrl/Alt+Right 단어 이동이 본문 문단 경계를 넘도록 변경했다.
- 현재 문단 끝에서 다음 문단의 첫 단어 위치로 이동하고, 문단 시작에서 이전 문단의 이전 단어 시작으로 이동한다.
- 빈 문단처럼 visible text run이 없는 문단은 rhwp core paragraph metric fallback을 재사용한다.
- 일반 문단 경계와 빈 문단 경계의 word navigation 테스트를 추가했다.

## 이 작업을 진행한 이유

이전 작업으로 일반 좌/우 방향키는 문단 경계를 넘을 수 있게 됐지만, 단어 단위 이동은 여전히 현재 paragraph text 안에서만 offset을 계산했다. 실제 편집기에서는 문단 끝과 시작에서도 Ctrl/Alt+방향키가 자연스럽게 다음/이전 단어로 이동해야 한다.

WebView 없는 Flutter-native editor가 문서 작성 도구처럼 쓰이려면 단순 caret 이동뿐 아니라 단어 단위 이동, Shift 확장 선택 같은 반복 작업이 문서 구조를 따라야 한다. 이 기능은 선택/삭제/검색 같은 후속 편집 UX의 기반이기도 하다.

## 이 작업을 통해 배울점

- 단어 이동은 문단 내부 token 계산과 문단 간 구조 이동을 함께 처리해야 한다.
- visible layer tree의 text run이 없는 문단은 core metric fallback 없이는 navigation 대상에서 빠질 수 있다.
- Flutter-native editor의 키보드 UX는 작은 경계 조건을 계속 줄여가야 WebView fallback 의존을 낮출 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves by word with keyboard modifiers"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves by word across empty paragraphs"`
- `flutter analyze`
- `git diff --check`
