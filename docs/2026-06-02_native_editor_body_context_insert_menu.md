# 2026-06-02 native editor body context insert menu

## 작업한 내용

- Flutter-native editor의 본문 context menu에 그림 넣기, 사각형, 타원, 선, 글상자 항목을 추가했다.
- 본문 context menu에 문단 추가, 쪽 나누기, 단 나누기 항목을 추가했다.
- 새 context menu 항목들은 기존 입력 리본과 같은 `_insertPicture`, `_insertShape`, `_insertParagraphAfterCursor`, `_insertPageBreak`, `_insertColumnBreak` 경로를 재사용한다.
- context menu에서 그림, 도형, 쪽 나누기가 실제 Rust command JSON으로 이어지는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream web editor는 문서 위에서 바로 편집 명령으로 진입하는 흐름이 중요하다. Flutter-native editor에도 입력 리본은 이미 있었지만, 본문 context menu는 표 만들기만 제공해서 그림, 도형, 쪽/단 나누기 같은 자주 쓰는 입력 명령은 리본으로 이동해야 했다.

WebView fallback 없이 Flutter 위젯 에디터를 실제 편집기로 키우려면 같은 command라도 ribbon, shortcut, context menu 같은 진입 경로를 계속 맞춰야 한다. 이번 작업은 새 문서 엔진 기능을 추가하지 않고 기존 Rust command bridge를 더 자연스러운 Flutter UI 경로에 연결한 것이다.

## 이 작업을 통해 배울점

- Flutter-native editor 포팅은 command 구현뿐 아니라 사용자가 명령에 접근하는 진입 경로까지 포함한다.
- context menu 항목은 별도 구현을 만들기보다 ribbon handler를 재사용해야 문서 변경 동작과 undo/refresh 처리가 일관된다.
- page hit-test 기반 context menu는 우클릭 위치를 현재 cursor로 반영하므로, 테스트도 클릭 위치 기준 offset을 검증해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu inserts body objects and breaks"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu copies selected text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor insert ribbon inserts shape presets"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts page and column breaks"`
- `flutter analyze`
- `git diff --check`
