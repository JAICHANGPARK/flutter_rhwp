# Native editor font size shortcuts

## 작업한 내용

- Flutter-native editor에서 `Ctrl/Cmd+Shift+Period`로 글자 크기를 한 단계 키우고, `Ctrl/Cmd+Shift+Comma`로 한 단계 줄이는 단축키를 추가했다.
- 실제 키 입력이 `Period/Comma` 또는 `Greater/Less`로 들어오는 경우를 모두 처리했다.
- 기존 format ribbon의 글자 크기 stepper와 같은 `_fontSizeStep` 및 `applyCharFormat` 경로를 사용하도록 했다.
- 선택 영역에 단축키가 적용될 때 `applyCharFormatRange` 명령이 생성되는 widget test를 추가했다.
- README와 CHANGELOG에 native editor 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

WebView 기반 full editor를 유지하면서도 Flutter 위젯 기반 editor를 실제 편집기로 키우려면 마우스 toolbar 조작뿐 아니라 키보드 중심 편집 흐름이 필요하다. 글자 크기 변경은 upstream editor의 서식 기능과 맞닿아 있고, 기존 character-format command API를 그대로 재사용할 수 있어 작은 단위로 native editor 완성도를 올리기 좋다.

## 이 작업을 통해 배울점

- Flutter desktop/web의 Shift 조합 키는 플랫폼과 입력 경로에 따라 기호 키(`Greater/Less`) 또는 원래 키(`Period/Comma`)로 들어올 수 있어 둘 다 처리하는 편이 안전하다.
- toolbar 버튼과 keyboard shortcut이 같은 내부 command path를 공유하면 선택 영역, 표 셀, collapsed pending format 같은 기존 편집 상태 처리를 다시 구현하지 않아도 된다.
- HWP 글자 크기는 pt 문자열이 아니라 내부 단위 값으로 command에 전달되므로 10.0pt는 `1000`, 11.0pt는 `1100`으로 검증하는 것이 맞다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor steps font size from keyboard shortcuts"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
