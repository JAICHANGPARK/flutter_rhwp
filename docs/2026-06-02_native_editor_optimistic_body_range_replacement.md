# 2026-06-02 Native Editor Optimistic Body Range Replacement

## 작업한 내용

- Flutter-native editor에서 multi-paragraph body selection 위에 바로 타이핑하는 경우 Rust `deleteRange` command 완료를 기다리지 않고 pending delete masks와 replacement text overlay를 먼저 표시하도록 변경했다.
- 선택 교체 입력 시 화면의 caret는 selection 시작 paragraph의 replacement text 뒤로 즉시 이동하지만, Rust command 큐에는 원래 multi-paragraph selection range를 보존해서 삭제와 삽입이 올바른 paragraph/offset으로 실행되도록 했다.
- 느린 `deleteRange` command 중에도 여러 paragraph selection mask와 새 글자가 보이고 page SVG refresh/render가 발생하지 않는 widget test를 추가했다.

## 이 작업을 진행한 이유

- 단일 paragraph body selection replacement는 command 완료 전 optimistic overlay를 쓰게 되었지만, multi-paragraph replacement는 `deleteRange` 완료 전 피드백이 늦을 수 있었다.
- 사용자가 여러 줄 또는 여러 문단을 선택한 뒤 바로 타이핑할 때 overlay가 늦으면 native editor가 입력을 놓치거나 화면을 refresh하는 것처럼 느껴진다.
- WebView 없이 Flutter-native editor를 실제 편집기로 만들려면 단일 selection뿐 아니라 paragraph를 가로지르는 selection replacement도 즉시 반응해야 한다.

## 이 작업을 통해 배울점

- body replacement는 같은 section 안에서는 `deleteText`와 `deleteRange`를 같은 optimistic overlay 원칙으로 다룰 수 있다.
- pending delete mask는 `RhwpSelectionRange` 그대로 보존하고, pending text overlay는 normalized start cursor에 붙이면 multi-paragraph replacement 피드백이 안정적으로 보인다.
- 실제 문서 구조 변경은 Rust core가 처리하되, 사용자 입력 직후의 시각 피드백은 Flutter overlay가 먼저 책임지는 설계가 중요하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews multi-paragraph body replacement"`
- `flutter test test/rhwp_widget_test.dart --plain-name "multi-paragraph selection"`
- `flutter test test/rhwp_widget_test.dart --plain-name "text input"`
- `flutter analyze`
- `git diff --check`
