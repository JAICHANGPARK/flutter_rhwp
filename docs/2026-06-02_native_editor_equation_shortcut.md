# Native editor equation shortcut

## 작업한 내용

- Flutter-native editor에 `Ctrl/Cmd+Alt+E` 수식 삽입 단축키를 추가했다.
- 일반 `Ctrl/Cmd+E` 가운데 정렬 단축키와 충돌하지 않도록 Alt가 함께 눌린 경우에만 수식 dialog를 연다.
- 기존 `_showInsertEquationDialog` 경로를 재사용해 input ribbon과 body context menu의 수식 삽입 동작과 같은 command path를 공유하도록 했다.
- shortcut으로 수식 dialog를 열고 script, font size, color를 입력한 뒤 `insertEquation` 명령이 생성되는 widget test를 추가했다.
- README와 CHANGELOG에 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 editor가 WebView fallback을 대체해 가려면 reference/object insertion도 toolbar 클릭에만 의존하지 않아야 한다. 수식은 HWP 문서에서 자주 쓰이는 입력 기능이고 이미 native dialog와 command API가 있으므로, shortcut 진입점을 추가해 실제 문서 편집 흐름을 넓혔다.

## 이 작업을 통해 배울점

- `Ctrl/Cmd+E`는 paragraph center alignment로 유지해야 하므로 수식 삽입은 `Ctrl/Cmd+Alt+E`로 먼저 분기해야 한다.
- shortcut, ribbon, context menu가 같은 `_showInsertEquationDialog` 경로를 공유하면 dialog validation, command 생성, caret 이동을 중복 구현하지 않아도 된다.
- dialog를 여는 shortcut 테스트는 key event 이후 `pumpAndSettle`로 overlay가 열린 상태를 확인한 뒤 입력을 진행해야 안정적이다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor opens equation dialog with shortcut"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
