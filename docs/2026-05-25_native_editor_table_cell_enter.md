# 2026-05-25 native editor table cell enter

## 작업한 내용

- `RhwpNativeEditor`에서 table cell selection이 활성화된 경우 Enter/NumpadEnter를 본문 문단 나누기로 보내지 않도록 했다.
- Enter가 현재 active table cell로 selection을 collapse하고 editor focus를 유지하도록 했다.
- multi-cell range selection 상태에서도 active cell 하나로 진입한 뒤 텍스트 입력이 해당 cell에 적용되도록 했다.
- widget test로 Enter가 `splitParagraph` command를 만들지 않고 이후 IME text input이 selected cell command로 들어가는지 검증했다.

## 이 작업을 진행한 이유

- upstream `rhwp/web/editor.js`는 `cellSelected` mode에서 Enter를 cell text edit 진입으로 처리한다.
- Flutter-native editor도 표 선택 상태에서 Enter가 본문 문단을 나누면 사용자가 선택한 표 context와 다른 문서 위치가 수정될 수 있다.
- 표 편집 UX는 mouse selection, keyboard navigation, text input이 같은 active cell model을 공유해야 한다.

## 이 작업을 통해 배울점

- 같은 Enter 키라도 editor state에 따라 body paragraph split과 table cell edit 진입이 분리되어야 한다.
- table cell selection은 range selection과 active cell을 함께 들고 있어야 keyboard action 이후 text input 대상이 명확하다.
- view/selection state 변경은 Rust edit command 없이 처리하고, 실제 text commit 순간에만 cell edit command를 보내는 것이 맞다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor enters selected table cell with enter"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves selected table cells with keyboard"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts text into selected table cell"`
- `dart format --set-exit-if-changed lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `git diff --check`
- `flutter analyze`
- `flutter test`
- `flutter test` in `example/`
- `cargo fmt --check` in `rust/`
- `cargo test` in `rust/`
