# 2026-05-25 native editor table cell keyboard navigation

## 작업한 내용

- `RhwpNativeEditor`에서 table cell selection이 활성화된 경우 ArrowLeft/Right/Up/Down을 셀 이동으로 처리하도록 했다.
- Shift+Arrow는 현재 active cell과 이동 대상 cell 사이의 rectangular range selection을 만들도록 했다.
- Tab과 Shift+Tab은 같은 table의 page-layer cell 순서 기준으로 다음/이전 cell을 선택하도록 했다.
- 키보드 표 이동은 view/selection state만 바꾸고 Rust edit command를 만들지 않도록 했다.
- widget test로 Arrow 이동, Shift+Arrow range extension, Tab/Shift+Tab 이동, command 미발생을 검증했다.

## 이 작업을 진행한 이유

- upstream `rhwp/web/editor.js`는 cellSelected mode에서 Arrow와 Tab으로 표 셀을 이동한다.
- Flutter-native editor가 WebView fallback 없이 실제 편집 surface가 되려면 mouse hit testing만으로는 부족하고, 표 편집에서 기대되는 keyboard workflow가 필요하다.
- 표 셀 이동은 문서 내용을 수정하지 않으므로 undo stack이나 document command가 아니라 controller selection state로 처리해야 한다.

## 이 작업을 통해 배울점

- table cell navigation은 단순 row/column 증감보다 rowspan/colspan을 고려한 이웃 cell 탐색이 필요하다.
- page-layer tree의 table cell geometry와 source indexes를 함께 사용하면 Flutter overlay selection과 Rust command context를 같은 모델로 유지할 수 있다.
- Shift+Arrow 확장은 active cell과 anchor cell을 분리해서 생각해야 range selection이 자연스럽다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves selected table cells with keyboard"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor drags table cells to extend table edit range"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts text into selected table cell"`
- `dart format --set-exit-if-changed lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `git diff --check`
- `flutter analyze`
- `flutter test`
- `flutter test` in `example/`
- `cargo fmt --check` in `rust/`
- `cargo test` in `rust/`
