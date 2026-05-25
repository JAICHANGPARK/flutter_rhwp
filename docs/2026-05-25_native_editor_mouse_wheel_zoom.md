# 2026-05-25 native editor mouse wheel zoom

## 작업한 내용

- `RhwpNativeEditor` viewport에서 Ctrl/Cmd+mouse wheel을 zoom in/out으로 처리하도록 했다.
- modifier가 없는 일반 wheel event는 zoom을 바꾸지 않고 기존 viewer scroll 흐름에 맡기도록 했다.
- zoom 변경은 기존 `RhwpEditorController`를 사용해 toolbar와 status bar 표시가 함께 갱신되도록 했다.
- widget test로 일반 wheel 미반응, Ctrl+wheel 확대/축소, edit command 미발생을 검증했다.

## 이 작업을 진행한 이유

- upstream `rhwp/web/editor.js`는 Ctrl+mouse wheel zoom을 제공한다.
- Flutter-native editor가 WebView fallback 없이 실제 editor surface가 되려면 toolbar 버튼과 keyboard shortcut뿐 아니라 viewport interaction도 문서 편집기 관례를 따라야 한다.
- zoom은 view state이므로 Rust document command나 undo stack을 건드리지 않아야 한다.

## 이 작업을 통해 배울점

- Flutter에서는 `PointerSignalEvent`를 editor viewport에서 받아 modifier key 상태와 함께 해석할 수 있다.
- mouse wheel zoom은 page overlay hit testing과 별도로 viewer surface 전체에 붙이는 편이 자연스럽다.
- toolbar, status bar, pointer interaction은 같은 controller state를 공유해야 zoom UI가 일관된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor view controls synchronize zoom state"`
- `dart format --set-exit-if-changed lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `git diff --check`
- `flutter analyze`
- `flutter test`
- `flutter test` in `example/`
- `cargo fmt --check` in `rust/`
- `cargo test` in `rust/`
