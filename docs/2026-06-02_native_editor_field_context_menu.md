# Native editor field context menu

## 작업한 내용

- Flutter-native editor의 body context menu에 `필드 목록`, `누름틀 속성`, `필드 삭제` 액션을 추가했다.
- Table cell text-editing context menu에도 같은 field 액션을 추가했다.
- 기존 tools ribbon field command path를 재사용해 body는 `getFieldInfoAt`, `updateClickHereProperties`, `removeFieldAt`을 호출하고, table cell은 `removeFieldAtInTableCell`을 호출하도록 했다.
- Body field properties update와 remove flow, table-cell field remove flow를 widget test로 검증했다.
- README와 CHANGELOG에 field context-menu 지원 범위를 반영했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView fallback 없이 실제 편집 화면으로 쓰이려면 ribbon뿐 아니라 문서 표면에서 바로 뜨는 context menu도 충분해야 한다. Upstream web editor가 DOM 이벤트와 JS toolbar/context menu로 편집 명령을 연결하는 구조이므로, Flutter 쪽에서도 같은 사용자 진입점을 위젯 기반으로 늘리는 작업이 필요했다.

## 이 작업을 통해 배울점

- 이미 노출된 Rust command를 재사용하면 새 core API를 만들지 않고도 native editor UX를 빠르게 확장할 수 있다.
- Body cursor와 table-cell cursor는 field command envelope가 다르므로 context menu 테스트에서 두 경로를 따로 검증해야 한다.
- 긴 context menu는 테스트 기본 viewport 밖으로 나갈 수 있어, 메뉴 항목을 직접 누르는 widget test에는 충분한 테스트 viewport를 지정해야 한다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor context menu edits body field controls|RhwpNativeEditor context menu removes table cell field controls"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
