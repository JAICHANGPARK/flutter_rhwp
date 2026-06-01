# 2026-06-02 Native Editor Cut Preview

## 작업한 내용

- Flutter-native editor의 body text cut 경로를 deferred refresh 기반으로 바꿨다.
- active table-cell text selection을 `Ctrl+X`로 잘라낼 때 pending deletion mask와 collapsed cell caret를 Rust delete command 완료 전에 먼저 표시하도록 했다.
- 느린 `deleteText`와 `deleteTextInTableCell` command 중에도 page SVG refresh가 발생하지 않고 clipboard/export/delete command 순서가 유지되는 widget test를 추가했다.

## 이 작업을 진행한 이유

- typing과 paste는 optimistic overlay로 개선됐지만, cut은 선택 영역 삭제 직후의 시각 피드백이 Rust command 완료에 묶일 수 있었다.
- 사용자가 선택 텍스트를 잘라낼 때 삭제 mask와 caret 이동이 바로 보이지 않으면 Flutter-native editor가 입력을 멈춘 것처럼 느껴진다.
- WebView 없이 Flutter 위젯 에디터를 완성하려면 타이핑, 붙여넣기, 잘라내기가 같은 입력 피드백 모델을 따라야 한다.

## 이 작업을 통해 배울점

- cut은 clipboard export와 실제 삭제 command가 모두 포함된 복합 작업이므로 clipboard 상태는 먼저 보존하고, 삭제 시각 효과는 Flutter overlay가 즉시 맡는 구조가 적합하다.
- table-cell text cut은 cell context를 pending deletion overlay에 같이 넘겨야 삭제 mask가 body text run이 아니라 셀 내부 텍스트에 정확히 붙는다.
- deferred refresh는 command 완료 후 rendered SVG를 source of truth로 다시 맞추고, 그 전까지 Flutter overlay가 사용자의 즉시 피드백을 책임지는 역할 분리가 중요하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews body text cut"`
- `flutter test test/rhwp_widget_test.dart --plain-name "previews table cell text cut"`
- `flutter test test/rhwp_widget_test.dart --plain-name "copies cuts and pastes selected text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "copies and cuts selected table cell text range"`
- `flutter analyze`
- `git diff --check`
