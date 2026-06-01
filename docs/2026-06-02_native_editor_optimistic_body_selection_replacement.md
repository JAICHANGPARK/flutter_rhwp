# 2026-06-02 Native Editor Optimistic Body Selection Replacement

## 작업한 내용

- Flutter-native editor에서 단일 paragraph body selection 위에 바로 타이핑하는 경우 Rust `deleteText` command 완료를 기다리지 않고 pending delete mask와 replacement text overlay를 먼저 표시하도록 변경했다.
- 선택 교체 입력 시 화면의 caret는 replacement text 뒤로 즉시 이동하지만, Rust command 큐에는 원래 body selection range를 보존해서 삭제와 삽입이 올바른 offset으로 실행되도록 했다.
- 느린 `deleteText` command 중에도 selection mask와 새 글자가 보이고 page SVG refresh/render가 발생하지 않는 widget test를 추가했다.

## 이 작업을 진행한 이유

- collapsed body/table-cell 입력은 command 완료 전 optimistic overlay를 쓰게 되었지만, body selection replacement는 삭제 command가 끝난 뒤에야 pending mask와 새 글자가 생길 수 있었다.
- 사용자가 선택 영역 위에 바로 타이핑할 때 피드백이 늦으면 입력마다 문서가 멈추거나 refresh되는 것처럼 보인다.
- WebView 없이 Flutter-native editor를 실제 편집기로 만들려면 선택 삭제와 새 입력도 Flutter overlay에서 즉시 반응해야 한다.

## 이 작업을 통해 배울점

- 선택 replacement는 화면의 optimistic cursor와 Rust command에 전달할 원래 selection range를 분리해야 한다.
- 단일 paragraph replacement는 `deleteText`와 `insertText`로 안정적으로 표현할 수 있지만, multi-paragraph replacement는 `deleteRange`와 레이아웃 변화가 커서 별도 정책이 필요하다.
- pending delete mask와 pending text overlay를 command 완료 전부터 기록하면 느린 Rust command 중에도 사용자가 편집 위치를 잃지 않는다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews selected body text replacement"`
- `flutter test test/rhwp_widget_test.dart --plain-name "text input"`
- `flutter test test/rhwp_widget_test.dart --plain-name "rapid text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "replaces multi-paragraph selection"`
- `flutter analyze`
- `git diff --check`
