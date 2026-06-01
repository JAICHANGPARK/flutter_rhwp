# 2026-06-02 native editor context reference menu

## 작업한 내용

- Flutter-native editor의 본문 context menu에 각주 넣기, 수식 넣기, 책갈피 항목을 추가했다.
- 새 항목들은 입력 리본의 `_insertFootnote`, `_showInsertEquationDialog`, `_showBookmarkDialog` 흐름을 그대로 재사용한다.
- context menu에서 각주 command, 수식 dialog command, 책갈피 dialog command가 Rust command JSON으로 이어지는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

입력 리본에는 각주, 수식, 책갈피 기능이 있었지만 본문 context menu에서는 접근할 수 없었다. 문서 편집 중 우클릭 메뉴에서 바로 참조/입력 도구로 들어가는 흐름은 WebView 기반 full editor를 대체할 Flutter-native editor에 필요한 사용성이다.

새 Rust API를 만들기보다 이미 검증된 리본 handler를 재사용했다. 이렇게 해야 cursor, selection 삭제, undo snapshot, refresh 처리가 ribbon과 context menu에서 같은 방식으로 유지된다.

## 이 작업을 통해 배울점

- 같은 편집 command라도 toolbar, shortcut, context menu 진입 경로를 모두 채워야 실제 editor UX에 가까워진다.
- dialog 기반 명령은 context menu에서도 기존 dialog component를 재사용하면 상태 관리가 단순해진다.
- page hit-test로 context menu를 열면 우클릭 위치가 cursor 기준이 되므로, reference 삽입 테스트도 해당 offset 기준으로 검증해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu inserts references"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu inserts body objects and breaks"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toolbar applies insert and delete commands"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor insert ribbon adds a bookmark"`
- `flutter analyze`
- `git diff --check`
