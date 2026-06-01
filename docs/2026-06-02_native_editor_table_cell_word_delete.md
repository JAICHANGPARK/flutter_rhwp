# 2026-06-02 native editor table cell word delete

## 작업한 내용

- Flutter-native editor에서 표 셀 텍스트 편집 중 Ctrl/Alt+Backspace, Ctrl/Alt+Delete가 한 글자 삭제가 아니라 단어 삭제로 동작하도록 변경했다.
- 같은 셀 문단 안의 단어 삭제는 기존 `deleteTextInTableCell` command에 count를 넘겨 처리한다.
- 셀 문단 경계를 넘는 단어 삭제를 위해 Dart/Rust bridge에 `deleteRangeInTableCell` command를 추가하고, rhwp core의 cell-context `delete_range_native` 경로에 연결했다.
- 표 셀 문단 텍스트를 page layer tree에서 복원해 기존 `_wordBoundaryOffset` 규칙을 재사용하도록 했다.
- command serialization, document convenience API, Rust bridge dispatch, Flutter widget keyboard path 테스트를 추가했다.

## 이 작업을 진행한 이유

본문 단어 삭제는 문단 경계를 넘도록 개선됐지만, 표 셀 편집 모드에서는 Ctrl/Alt+Backspace/Delete가 기존 문자 삭제 함수로 빠져 한 글자만 지웠다. 실제 HWP 편집기에서는 표 셀 안에서도 본문과 같은 키보드 편집 규칙이 필요하다.

표 셀은 별도 cell paragraph 구조를 갖기 때문에 본문 `deleteRange`만으로는 충분하지 않다. Rust core가 이미 cell context 기반 range delete를 지원하므로, Flutter 플러그인 API에서 이를 명시적으로 노출하고 native editor가 사용하도록 연결했다.

## 이 작업을 통해 배울점

- Flutter-native editor에서 본문과 표 셀 편집은 같은 UX를 가져야 하지만, command payload는 문서 구조에 맞게 분리해야 한다.
- 표 셀 내부 문단을 넘는 삭제는 단일 `deleteTextInTableCell` 반복보다 range command로 모델링하는 편이 core 동작과 맞다.
- page layer tree는 hit-test뿐 아니라 표 셀 내부 word-boundary 계산에도 재사용할 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart --plain-name "table cell commands serialize to Rust envelopes"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor deletes table cell words with keyboard modifiers"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor splits and merges table cell paragraphs with keys"`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
- `cargo test --manifest-path rust/Cargo.toml applies_table_cell_paragraph_split_and_merge_commands`
- `flutter analyze`
- `git diff --check`
