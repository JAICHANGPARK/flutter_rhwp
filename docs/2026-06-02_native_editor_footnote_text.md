# Native editor footnote text

## 작업한 내용

- Flutter-native 에디터의 입력 리본에 `Edit footnote text` 버튼을 추가했다.
- 현재 커서 주변의 각주 마커를 `getFootnoteAtCursor`로 찾고, `getFootnoteInfo`로 각주 본문을 읽어 dialog에 표시하도록 연결했다.
- dialog에서 입력한 텍스트를 `deleteTextInFootnote`와 `insertTextInFootnote` command로 각주 첫 문단에 반영하도록 구현했다.
- Dart 공개 API와 Rust facade command enum에 각주 조회/편집 command를 추가했다.
- 위젯 테스트에서 버튼, dialog 초기값, command 순서, undo snapshot, `onChanged` 호출을 검증했다.

## 이 작업을 진행한 이유

rhwp upstream 웹 에디터는 각주 같은 문서 보조 영역도 브라우저 DOM 이벤트와 WASM API를 조합해서 편집한다. Flutter-native 에디터가 WebView fallback을 대체하려면 본문 입력뿐 아니라 각주, 필드, 표, 머리말/꼬리말 같은 보조 편집 surface를 Flutter 위젯과 Rust command로 직접 처리해야 한다.

## 이 작업을 통해 배울점

- Flutter UI만 추가해도 충분하지 않고, command JSON, Rust facade, vendored rhwp native API가 같은 단위로 맞물려야 native editor 기능이 된다.
- 각주 본문은 본문 cursor와 별도 control 내부 문단을 가진다. 따라서 먼저 마커 hit-test를 하고, control index를 기준으로 내부 문단 편집 command를 호출해야 한다.
- WebView 에디터 포팅은 화면을 복제하는 작업이 아니라 문서 구조별 편집 surface를 하나씩 Flutter 위젯으로 옮기는 작업이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --name "insert ribbon edits footnote text"`
- `flutter test test/rhwp_widget_test.dart --name "inserts page and column breaks"`
- `flutter test test/rhwp_widget_test.dart`
- `flutter test test/flutter_rhwp_test.dart`
- `flutter analyze`
- `cargo check` (`rust/`)
- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/rhwp_widget_test.dart test/flutter_rhwp_test.dart`
