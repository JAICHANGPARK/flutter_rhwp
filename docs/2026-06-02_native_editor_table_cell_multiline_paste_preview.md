# 2026-06-02 Native Editor Table Cell Multiline Paste Preview

## 작업한 내용

- Flutter-native editor의 selected table-cell multiline paste 경로에 optimistic preview를 추가했다.
- 선택된 셀 텍스트를 여러 줄 clipboard text로 대체할 때 pending deletion mask, 첫 줄 pending text overlay, 최종 cell caret 위치를 Rust command 완료 전에 먼저 표시하도록 했다.
- 느린 `insertTextInTableCell` command 중에도 page SVG refresh가 발생하지 않고, `deleteTextInTableCell`/`insertTextInTableCell`/`splitParagraphInTableCell` command 순서가 유지되는 widget test를 추가했다.

## 이 작업을 진행한 이유

- body multiline paste는 즉시 피드백을 제공하게 되었지만, table-cell multiline paste는 여전히 command 완료 전 화면 반응이 늦을 수 있었다.
- 사용자가 표 안에서 여러 줄 텍스트를 붙여넣을 때 셀 caret와 선택 삭제 상태가 바로 보이지 않으면 native editor가 멈춘 것처럼 느껴진다.
- upstream web editor 수준의 Flutter 위젯 에디터를 만들려면 body와 table cell 입력 경로가 같은 optimistic overlay 원칙을 공유해야 한다.

## 이 작업을 통해 배울점

- table-cell paste는 active cell paragraph/offset을 먼저 계산하고, 실제 문서 변경은 Rust core command 순서에 맡기는 방식이 안정적이다.
- pending deletion mask와 pending text overlay는 cell text context를 함께 기록해야 body text run으로 잘못 붙지 않는다.
- Flutter-native editor의 입력 UX는 단일 타이핑, selection replacement, body paste, table-cell paste가 같은 deferred refresh 모델을 공유할 때 일관성이 생긴다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews multiline table cell paste"`
- `flutter test test/rhwp_widget_test.dart --plain-name "pastes multiline text into selected table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "copies cuts and pastes selected table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "pastes copied table cell text through HTML import"`
- `flutter analyze`
- `git diff --check`
