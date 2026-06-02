# Native editor footnote shortcut

## 작업한 내용

- Flutter-native editor에 `Ctrl/Cmd+Alt+F` 각주 삽입 단축키를 추가했다.
- 기존 `_insertFootnote` 경로를 재사용해 input ribbon과 body context menu의 각주 삽입 동작과 같은 command path를 공유하도록 했다.
- 일반 `Ctrl/Cmd+F` 검색 단축키와 충돌하지 않도록 Alt가 함께 눌린 경우에만 각주 삽입으로 먼저 분기했다.
- collapsed cursor 위치에서 단축키가 `insertFootnote` 명령을 생성하고 caret을 한 글자 앞으로 이동시키는 widget test를 추가했다.
- README와 CHANGELOG에 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 editor가 WebView fallback을 대체해 가려면 reference 삽입도 ribbon 클릭에만 의존하지 않아야 한다. 각주는 문서 편집에서 자주 쓰는 reference 기능이고 이미 native command API가 준비되어 있으므로, 키보드 진입점을 추가해 실제 편집 흐름을 넓혔다.

## 이 작업을 통해 배울점

- `Ctrl/Cmd+F`는 검색으로 유지해야 하므로 footnote shortcut은 `Ctrl/Cmd+Alt+F`처럼 명확히 분기해야 한다.
- shortcut, ribbon, context menu가 같은 `_insertFootnote` 경로를 공유하면 선택 삭제, caret 이동, edit refresh 처리를 중복 구현하지 않아도 된다.
- reference insertion은 table-cell edit mode에서 제한되는 기존 guard를 그대로 공유하는 편이 안전하다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor inserts footnote with shortcut"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
