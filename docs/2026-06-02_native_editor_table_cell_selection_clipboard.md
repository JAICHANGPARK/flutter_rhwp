# 2026-06-02 native editor table cell selection clipboard

## 작업한 내용

- Flutter-native editor에서 표 셀 내부 텍스트 선택이 있을 때 `Ctrl+C`가 선택된 cell paragraph range만 plain text로 복사하도록 연결했다.
- 같은 선택 상태에서 `Ctrl+X`가 선택 range를 복사한 뒤 `deleteTextInTableCell` 또는 `deleteRangeInTableCell`로 삭제하도록 연결했다.
- 셀 내부 선택 복사/잘라내기에도 `exportSelectionInCellHtml`을 사용해 같은 에디터 안에서 붙여넣을 때 rich HTML clipboard 경로를 유지하도록 했다.
- 같은 셀 문단 선택과 여러 셀 문단을 가로지르는 선택을 각각 위젯 테스트로 검증했다.

## 이 작업을 진행한 이유

표 셀 내부 텍스트 선택은 overlay, 삭제, 입력 교체까지 연결되었지만 복사/잘라내기는 여전히 셀 전체 선택 경로를 타고 있었다. Flutter-native editor가 실제 문서 편집기로 동작하려면 사용자가 선택한 범위와 clipboard에 들어가는 범위가 일치해야 한다.

WebView fallback 없이 Flutter 위젯 에디터를 키우려면 body text와 table-cell text의 keyboard shortcut, clipboard, rich paste 흐름이 같은 수준으로 맞춰져야 한다.

## 이 작업을 통해 배울점

- 표 셀 전체 선택과 셀 내부 텍스트 선택은 같은 `RhwpTableCellSelection`을 공유하지만 clipboard semantics는 다르므로 먼저 `hasTextSelection`을 분기해야 한다.
- cell paragraph를 가로지르는 선택은 텍스트 추출에서 줄바꿈을 보존하고, HTML export에서는 normalized start/end cell paragraph range를 그대로 넘겨야 한다.
- 잘라내기는 clipboard 저장과 편집 command를 한 흐름으로 묶되, 삭제 뒤에는 selection anchor를 지워 collapsed caret 상태로 되돌려야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "selected table cell text range"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
