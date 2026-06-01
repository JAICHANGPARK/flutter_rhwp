# 2026-06-02 native editor table cell selection paste

## 작업한 내용

- Flutter-native editor에서 표 셀 내부 텍스트 선택 위에 rich HTML clipboard를 붙여넣을 때 선택 range를 먼저 삭제하고 같은 위치에 `pasteHtmlInCell`을 실행하도록 했다.
- 표 셀 텍스트 편집 중 plain text clipboard에 줄바꿈이 포함되어 있으면 body 문단 paste 경로로 빠지지 않고 셀 문단 안에서 처리하도록 했다.
- multiline plain text paste는 선택 range 삭제 후 `insertTextInTableCell`, `splitParagraphInTableCell`을 순서대로 호출해 셀 내부 문단을 생성한다.
- rich HTML paste replacement와 multiline plain-text paste replacement를 위젯 테스트로 검증했다.

## 이 작업을 진행한 이유

표 셀 내부 텍스트 선택은 복사/잘라내기까지 연결되었지만, 붙여넣기에서는 rich HTML이 선택 range를 지우지 않고 active offset에 바로 들어갈 수 있었다. 또한 줄바꿈이 포함된 plain text는 table-cell edit mode에서 body 문단 paste 함수로 흘러가 결과적으로 붙지 않는 경로가 있었다.

Flutter-native editor가 WebView fallback 없이 실제 편집기로 동작하려면 선택, 삭제, 복사, 잘라내기, 붙여넣기가 같은 selection 모델을 공유해야 한다.

## 이 작업을 통해 배울점

- rich clipboard paste는 plain text paste와 달리 `_insertCommittedText`를 거치지 않으므로 selection deletion을 별도로 처리해야 한다.
- table-cell edit mode에서 multiline paste는 body paragraph split이 아니라 cell paragraph split command를 사용해야 한다.
- clipboard routing은 table range selection과 table-cell text editing을 먼저 구분해야 사용자가 기대한 붙여넣기 범위를 유지할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "HTML paste"`
- `flutter test test/rhwp_widget_test.dart --plain-name "multiline text into selected table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
