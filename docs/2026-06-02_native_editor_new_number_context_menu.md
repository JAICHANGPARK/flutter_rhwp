# Native editor new-number context menu

## 작업한 내용

- Flutter-native editor의 body context menu에 `새 번호로 시작` 액션을 추가했다.
- 기존 page ribbon의 `_showInsertNewNumberDialog`와 `insertNewNumber` command path를 재사용했다.
- Context menu에서 새 번호 dialog를 열고 시작 번호를 입력했을 때 `insertNewNumber` command가 생성되는 widget test를 추가했다.
- README와 CHANGELOG에 body context-menu 새 번호 삽입 지원 내용을 반영했다.

## 이 작업을 진행한 이유

WebView fallback 없이 Flutter 위젯 에디터를 실제 편집 surface로 키우려면 리본뿐 아니라 문서 표면의 context menu에서도 주요 입력 명령을 실행할 수 있어야 한다. 새 번호 삽입은 이미 Rust/Dart command와 page ribbon 경로가 있으므로, body context menu에 진입점을 추가해 upstream 웹 에디터식 문서 표면 조작에 더 가깝게 만들었다.

## 이 작업을 통해 배울점

- 기존 dialog와 command path를 재사용하면 page ribbon과 context menu 동작 차이를 줄일 수 있다.
- Body context menu 액션은 table-cell selection에서는 노출되지 않아야 하므로, body 메뉴 목록에만 추가하는 것이 맞다.
- Dialog 기반 context-menu 액션은 menu item 노출, dialog 입력, 최종 command envelope까지 한 테스트에서 검증해야 한다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor context menu inserts body objects and breaks"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
