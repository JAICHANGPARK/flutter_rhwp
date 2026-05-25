# 2026-05-25 native editor object delete

## 작업한 내용

- Dart command surface에 `deleteObjectControl`을 추가했다.
- Rust facade가 `deleteObjectControl`을 받아 선택 개체 타입에 따라 rhwp core의 shape, picture, equation 삭제 API로 라우팅하도록 했다.
- `RhwpNativeEditor`에서 선택된 object/control이 있을 때 Delete, Backspace, Ctrl/Option+Delete 계열 입력이 본문 텍스트 삭제 대신 선택 개체 삭제로 동작하도록 연결했다.
- object selection 전용 context menu에 `개체 삭제` 액션을 추가했다.
- widget test와 command serialization test로 선택 개체 삭제 명령이 올바른 JSON envelope로 전달되는지 검증했다.

## 이 작업을 진행한 이유

upstream `rhwp/web` 에디터는 `text_selection.js`의 control hit-test 결과를 `editor.js`의 `objectSelected` 편집 상태로 넘겨 객체 선택을 별도로 다룬다. Flutter-native editor도 직전 단계에서 object selection을 표시할 수 있게 되었으므로, 다음 단계는 그 선택 상태를 실제 편집 command로 연결하는 것이다.

선택만 가능한 객체는 뷰어 기능에 가깝다. Delete/Backspace와 context menu 삭제가 붙어야 Flutter 위젯 기반 에디터가 WebView fallback 없이 실제 편집 surface로 성장할 수 있다.

## 배울점

- Flutter-native editor에서는 text selection, table cell selection, object selection이 서로 다른 command target이다. 입력 라우팅에서 현재 selection domain을 먼저 판별해야 잘못된 문서 영역을 수정하지 않는다.
- page layer tree는 화면 hit-test에 충분하지만, 문서 수정 command에는 section, paragraph, controlIndex 같은 model 좌표가 반드시 필요하다.
- Web editor의 DOM/Canvas 상태명을 그대로 옮기기보다, Flutter controller state와 Rust command envelope 사이의 계약을 작게 추가하는 방식이 유지보수에 유리하다.

## 검증

- `dart format --set-exit-if-changed lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `flutter test test/flutter_rhwp_test.dart --plain-name "object control commands serialize to Rust envelopes"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor deletes selected object controls"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu deletes selected objects"`
- `flutter analyze`
- `flutter test`
- `(cd example && flutter test)`
- `cargo fmt --check`
- `cargo test applies_commands_exports_and_reopens`
- `cargo test`
