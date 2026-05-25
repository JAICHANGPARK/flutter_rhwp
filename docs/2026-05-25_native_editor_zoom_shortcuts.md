# 2026-05-25 native editor zoom shortcuts

## 작업한 내용

- `RhwpNativeEditor`에서 Ctrl/Cmd+`=` 또는 `+` 단축키로 확대하도록 했다.
- Ctrl/Cmd+`-` 단축키로 축소하도록 했다.
- Ctrl/Cmd+`0` 단축키로 배율을 100%로 되돌리도록 했다.
- 단축키가 기존 `RhwpEditorController` zoom 상태를 사용하게 해서 view ribbon과 status bar가 같은 값으로 갱신되도록 했다.
- widget test로 확대, 축소, reset zoom 단축키와 문서 edit command 미발생을 검증했다.

## 이 작업을 진행한 이유

- upstream `rhwp/web/editor.js`는 Ctrl/Cmd 기반 zoom 단축키를 제공한다.
- Flutter-native 에디터가 WebView fallback 없이 실제 편집 surface가 되려면 toolbar 버튼뿐 아니라 문서 편집기에서 기대되는 keyboard workflow도 따라가야 한다.
- zoom은 문서 내용을 수정하지 않는 view state이므로 Rust edit command를 발생시키지 않고 controller 상태만 바꾸는 것이 맞다.

## 이 작업을 통해 배울점

- editor toolbar, status bar, keyboard shortcuts는 모두 같은 controller state를 바라봐야 UI가 엇갈리지 않는다.
- shortcut 처리는 edit command와 view command를 명확히 분리해야 undo stack과 document dirty state가 불필요하게 변하지 않는다.
- Flutter logical key는 main keyboard와 numpad key를 같이 처리해야 desktop keyboard 환경에서 동작이 자연스럽다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor view controls synchronize zoom state"`
- `dart format --set-exit-if-changed lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `git diff --check`
- `flutter analyze`
- `flutter test`
- `flutter test` in `example/`
- `cargo fmt --check` in `rust/`
- `cargo test` in `rust/`
