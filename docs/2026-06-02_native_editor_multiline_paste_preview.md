# 2026-06-02 Native Editor Multiline Paste Preview

## 작업한 내용

- Flutter-native editor의 body multiline paste 경로를 deferred refresh 기반으로 바꿨다.
- 여러 줄 clipboard text를 붙여넣을 때 첫 줄 pending text overlay와 최종 logical caret 위치를 Rust command 완료 전에 먼저 보여주도록 했다.
- 느린 `insertText` command 중에도 page SVG refresh가 발생하지 않고, `insertText`/`splitParagraph` command 순서가 유지되는 widget test를 추가했다.

## 이 작업을 진행한 이유

- 단일 글자 입력은 optimistic overlay로 개선됐지만, multiline paste는 여러 Rust command가 끝날 때까지 화면 피드백이 늦을 수 있었다.
- 사용자가 문단 여러 개를 붙여넣을 때 바로 caret가 이동하지 않으면 Flutter-native editor가 입력을 멈춘 것처럼 보인다.
- WebView fallback 없이 Flutter 위젯 에디터를 키우려면 타이핑뿐 아니라 paste 같은 대량 입력 경로도 같은 refresh 원칙을 따라야 한다.

## 이 작업을 통해 배울점

- Flutter overlay는 문서 구조의 source of truth가 아니라 command 완료 전 사용자 피드백을 담당하는 계층으로 두는 것이 안정적이다.
- multiline paste는 전체 문단 재레이아웃을 Rust render refresh에 맡기고, Flutter는 첫 줄 preview와 logical caret를 먼저 보여주는 방식이 현실적이다.
- 단일 입력과 paste 입력 모두 deferred refresh 규칙을 공유하면 Space/text 입력 때 보이던 per-key refresh 문제를 다른 입력 경로로 확장해서 줄일 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews multiline body paste"`
- `flutter test test/rhwp_widget_test.dart --plain-name "pastes multiline body text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "copies cuts and pastes selected text"`
- `flutter analyze`
- `git diff --check`
