# Native editor character effect shortcuts

## 작업한 내용

- Flutter-native editor에 character effect 키보드 단축키를 추가했다.
- `Ctrl/Cmd+Shift+X`는 취소선을 토글하고, `Ctrl/Cmd+Period`는 위첨자, `Ctrl/Cmd+Comma`는 아래첨자를 토글한다.
- 기존 `_toggleCharFormat` 경로를 사용해 선택 영역, 표 셀 텍스트, collapsed pending format 처리와 같은 내부 동작을 공유하도록 했다.
- 선택 영역에서 각 단축키가 `applyCharFormatRange` 명령으로 전달되는 widget test를 추가했다.
- README와 CHANGELOG에 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 editor가 WebView fallback을 대체해 가려면 toolbar 클릭뿐 아니라 문서 편집자가 기대하는 키보드 중심 서식 조작이 필요하다. 취소선, 위첨자, 아래첨자는 이미 native toolbar와 command API가 준비되어 있었지만 키보드 진입점이 부족했으므로, 같은 내부 경로를 재사용해 기능 표면을 넓혔다.

## 이 작업을 통해 배울점

- `Ctrl/Cmd+X`는 잘라내기로 유지해야 하므로 취소선은 Shift가 눌린 경우에만 먼저 분기해야 한다.
- 위첨자와 아래첨자는 서로 배타적인 상태이므로 `_toggleCharFormat`을 공유하면 `superscript/subscript` 상호 해제를 별도로 다시 구현하지 않아도 된다.
- keyboard shortcut, toolbar, context menu가 같은 command path를 쓰면 native editor 기능이 늘어나도 테스트 기대값과 상태 갱신 방식이 단순해진다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor applies character effect shortcuts"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
