# Native editor bookmark shortcut

## 작업한 내용

- Flutter-native editor에 `Ctrl/Cmd+Alt+B` 책갈피 dialog 단축키를 추가했다.
- 기존 `_showBookmarkDialog` 경로를 재사용해 input ribbon과 body context menu의 책갈피 add/delete/rename/go-to 동작과 같은 command path를 공유하도록 했다.
- 일반 `Ctrl/Cmd+B` 굵게 단축키와 충돌하지 않도록 Alt가 함께 눌린 경우에만 책갈피 dialog를 연다.
- shortcut으로 책갈피 dialog를 열고 새 책갈피를 추가했을 때 `getBookmarks`와 `addBookmark` 명령이 생성되는 widget test를 추가했다.
- README와 CHANGELOG에 책갈피 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 editor가 WebView fallback 없이 실제 편집기로 쓰이려면 자주 쓰는 참조 기능도 toolbar 클릭에만 의존하면 안 된다. 책갈피는 문서 탐색과 편집 위치 표시의 기본 기능이므로 shortcut 진입점을 추가해 upstream-style editor에 가까운 키보드 흐름을 보강했다.

## 이 작업을 통해 배울점

- `Ctrl/Cmd+B`는 bold 토글로 유지해야 하므로 책갈피는 `Ctrl/Cmd+Alt+B`로 먼저 분기해야 한다.
- shortcut, ribbon, context menu가 같은 dialog handler를 공유하면 command 생성과 validation을 중복하지 않아도 된다.
- dialog shortcut 테스트는 key event 이후 `pumpAndSettle`로 overlay를 안정화한 뒤 입력과 action 버튼을 검증해야 한다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor opens bookmark dialog with shortcut"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
