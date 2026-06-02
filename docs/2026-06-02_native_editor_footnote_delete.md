# Native editor footnote delete

## 작업한 내용

- Flutter-native 에디터의 입력 리본에 `Delete footnote` 버튼을 추가했다.
- 현재 커서 앞/뒤 각주 마커를 `getFootnoteAtCursor`로 찾고, `deleteFootnote` command로 본문 마커와 각주 본문을 함께 삭제하도록 연결했다.
- Dart command/API와 Rust facade command enum에 `deleteFootnote` 경로를 추가했다.
- 위젯 테스트에서 각주 삭제 버튼, undo snapshot, command 순서, cursor 복귀 위치, fake session 상태 변화를 검증했다.
- 공개 command envelope 테스트에 `deleteFootnote` 직렬화를 추가했다.

## 이 작업을 진행한 이유

각주 본문 편집만 가능하고 각주 자체를 제거할 수 없다면 Flutter-native 에디터는 여전히 WebView/full editor에 의존해야 한다. 각주 삭제는 본문 마커와 control 내부 본문을 함께 다루는 기능이라, Flutter UI가 문서 구조 단위 편집을 직접 수행하는 방향에 맞다.

## 이 작업을 통해 배울점

- 각주 삭제는 단순 텍스트 삭제가 아니라 control 삭제와 번호 재계산을 포함하므로 Rust 코어 command를 source of truth로 써야 한다.
- Flutter 위젯은 커서 주변 control을 찾는 hit command와 실제 edit command를 분리해서 호출해야 한다.
- WebView 에디터를 대체하는 작업은 보조 문서 요소별로 조회, 편집, 삭제 surface를 꾸준히 넓히는 방식이 현실적이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --name "insert ribbon deletes footnotes"`
- `flutter test test/rhwp_widget_test.dart --name "insert ribbon edits footnote text"`
- `flutter test test/flutter_rhwp_test.dart`
- `flutter analyze`
- `cargo check` (`rust/`)
- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
