# Native Editor Bookmark Navigation

## 작업한 내용

- Dart/Rust command bridge에 `getPageOfPosition` / `pageOfPosition` API를 추가했다.
- Flutter-native bookmark dialog에 선택한 책갈피로 이동하는 `이동` 액션을 추가했다.
- 이동 액션은 커서와 페이지 스크롤만 갱신하고, undo snapshot이나 `onChanged`를 만들지 않도록 분리했다.
- command serialization test와 widget test를 추가해 책갈피 이동이 문서 편집으로 기록되지 않는지 검증했다.

## 이 작업을 진행한 이유

upstream Web editor 수준의 네이티브 Flutter 에디터로 가려면 책갈피는 단순 생성/삭제뿐 아니라 문서 안에서 빠르게 이동하는 탐색 기능까지 갖춰야 한다. 기존 Flutter-native dialog는 목록, 추가, 삭제, 이름 변경은 가능했지만 선택한 책갈피 위치로 이동할 수 없었다.

Rust core에는 이미 문단 위치를 페이지로 해석하는 `getPageOfPosition` 경로가 있으므로, JS/WebView를 부르지 않고 FRB command bridge로 노출하는 것이 현재 구조와 맞다.

## 이 작업을 통해 배울점

- 탐색 명령과 편집 명령은 undo/onChanged 처리 경로를 분리해야 한다.
- 책갈피 위치 이동은 `section/paragraph/charPosition`을 cursor로 쓰고, 페이지 번호는 Rust core의 pagination query에서 받아오는 구조가 안정적이다.
- Flutter-native editor는 UI 기능을 추가할 때마다 Rust core query를 작은 public surface로 노출해 Web editor 의존도를 줄일 수 있다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test test/flutter_rhwp_test.dart --name "bookmark commands serialize to the Rust command envelope"`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor insert ribbon jumps to a bookmark"`
- `cargo check`
- `cargo test applies_commands_exports_and_reopens`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
