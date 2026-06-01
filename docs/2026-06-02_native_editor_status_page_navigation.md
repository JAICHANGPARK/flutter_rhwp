# Native Editor Status Page Navigation

## 작업한 내용

- Flutter-native editor 상태바에 이전/다음 페이지 버튼을 추가했다.
- 버튼은 `RhwpEditorController.previousPage()`와 `nextPage()`를 사용해 viewer scroll 상태와 같은 경로로 이동한다.
- 첫 페이지에서는 이전 버튼, 마지막 페이지에서는 다음 버튼이 비활성화되도록 했다.
- 기존 상태바 page tracking test를 확장해 버튼 이동과 경계 비활성화를 검증했다.

## 이 작업을 진행한 이유

upstream web editor는 페이지 정보와 페이지 이동을 편집 화면 chrome 안에서 바로 제공한다. Flutter-native editor도 WebView fallback 없이 실제 편집 surface가 되려면 보기 리본뿐 아니라 하단 상태바에서도 문서 탐색이 가능해야 한다.

이 기능은 문서 내용을 수정하지 않는 탐색 기능이므로 Rust command, undo snapshot, `onChanged`를 건드리지 않고 viewer controller 경로만 사용했다.

## 이 작업을 통해 배울점

- 문서 탐색 UI는 한 곳에서만 구현하기보다 리본과 상태바처럼 사용자가 자주 보는 위치에 같이 제공하는 편이 편집기 UX에 가깝다.
- viewer controller를 단일 이동 경로로 두면 리본, 단축키, 상태바가 같은 current-page synchronization을 공유할 수 있다.
- 상태바 버튼도 첫/마지막 페이지 경계를 명확히 비활성화해야 불필요한 scroll 요청과 혼란을 줄일 수 있다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor status bar tracks current page"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
