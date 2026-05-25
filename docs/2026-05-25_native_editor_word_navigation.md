# 2026-05-25 native editor word navigation

## 작업한 내용

- `RhwpNativeEditor`에서 Ctrl+ArrowLeft/Right와 Option+ArrowLeft/Right 단어 단위 이동을 추가했다.
- macOS 사용성을 위해 Option 조합을, Windows/Linux 사용성을 위해 Ctrl 조합을 같은 word navigation 경로로 처리한다.
- Shift 조합을 함께 누르면 현재 selection anchor를 유지한 채 이전/다음 단어 경계까지 선택을 확장한다.
- 단어 경계는 page layer tree의 같은 section/paragraph text run을 모아 계산한다.
- widget test fixture가 긴 text run 길이와 cluster를 표현할 수 있도록 문자열 길이 기반 source range와 cluster 생성을 지원했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터가 WebView 에디터를 대체하려면 일반 문서 편집기에서 기대하는 단어 단위 caret 이동이 필요하다.
- 단어 이동은 문서를 수정하지 않는 navigation이므로 Rust edit command와 undo/redo history를 만들면 안 된다.
- page layer tree text source를 기준으로 처리하면 Flutter 위젯에서도 DOM 없이 source position 기반 navigation을 구현할 수 있다.

## 이 작업을 통해 배울점

- keyboard navigation은 플랫폼별 관습이 달라서 macOS Option 키와 Windows/Linux Ctrl 키를 함께 고려해야 한다.
- 단어 이동은 렌더링 좌표가 아니라 같은 paragraph의 source text를 복원해서 separator 기준으로 계산하는 편이 안정적이다.
- 테스트 fixture가 실제 text length를 반영해야 search, selection, word navigation 같은 source offset 기반 기능을 함께 검증할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves by word with keyboard modifiers"`
