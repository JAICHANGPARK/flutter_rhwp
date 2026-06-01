# Native editor line spacing shortcuts

## 작업한 내용

- Flutter-native editor에 `Ctrl/Cmd+1`, `Ctrl/Cmd+2`, `Ctrl/Cmd+5` 줄간격 단축키를 추가했다.
- `Ctrl/Cmd+1`은 100%, `Ctrl/Cmd+2`는 200%, `Ctrl/Cmd+5`는 150% 줄간격을 적용한다.
- numpad 입력인 `Numpad1`, `Numpad2`, `Numpad5`도 같은 단축키로 처리했다.
- 기존 `_applyParagraphFormat` 경로를 재사용해 format ribbon, context menu, keyboard shortcut이 같은 paragraph-format command path를 공유하도록 했다.
- 선택된 여러 문단에 단축키가 `applyParaFormatRange` 명령으로 전달되는 widget test를 추가했다.
- README와 CHANGELOG에 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 editor가 실제 문서 편집기로 쓰이려면 ribbon 조작뿐 아니라 반복적인 문단 서식을 빠르게 적용하는 키보드 흐름이 필요하다. 줄간격 100%, 150%, 200%는 문서 편집기에서 자주 쓰는 조합이고 이미 native paragraph-format API가 준비되어 있으므로, 같은 내부 경로를 연결하는 것이 자연스럽다.

## 이 작업을 통해 배울점

- shortcut을 toolbar와 같은 `_applyParagraphFormat` 경로에 연결하면 본문/표 셀 대상 선택과 refresh 처리를 중복 구현하지 않아도 된다.
- `Ctrl/Cmd+0`은 기존 zoom reset 단축키로 유지하고, 줄간격은 `1`, `2`, `5`만 처리해 기존 zoom shortcut과 충돌하지 않게 해야 한다.
- numpad key도 함께 처리하면 데스크톱 키보드 환경에서 shortcut 동작이 더 예측 가능하다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor applies line spacing shortcuts"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
