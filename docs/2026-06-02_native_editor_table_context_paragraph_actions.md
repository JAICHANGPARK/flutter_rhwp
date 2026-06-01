# 2026-06-02 Native Editor Table Context Paragraph Actions

## 작업한 내용

- Flutter-native 에디터의 표 셀 텍스트 편집 context menu에 `문단 모양`, `왼쪽 정렬`, `가운데 정렬`, `오른쪽 정렬`, `양쪽 정렬` 항목을 추가했다.
- 이 문단 서식 그룹은 표 셀 텍스트 선택 또는 active cell text caret이 있을 때만 보이도록 기존 text formatting target 조건에 붙였다.
- 표 셀 전체 작업 context menu는 그대로 유지하고, 행/열/셀 작업 메뉴가 불필요하게 커지지 않도록 했다.
- context menu의 `가운데 정렬`이 active cell paragraph에 `applyParaFormatInTableCell` command를 보내는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

- WebView fallback 없이 Flutter-native editor로 가려면 표 셀 안에서도 body 편집과 같은 문단 서식 UX가 필요하다.
- 표 셀 텍스트는 문자 서식뿐 아니라 문단 정렬, 줄 간격, 여백 같은 문단 속성도 자주 편집된다.
- 기존 core 경로는 `_applyParagraphFormat`에서 표 셀 paragraph target을 이미 처리하고 있었지만, context menu에는 이 기능이 노출되어 있지 않았다.

## 이 작업을 통해 배울점

- 표 셀 context menu는 셀 레이아웃 작업과 텍스트 편집 작업을 구분해야 한다. 같은 `tableCellSelection`이라도 `isTextEditing` 상태에 따라 보여줄 액션이 달라진다.
- 이미 존재하는 command 경로라도 UI surface에 연결되지 않으면 실제 native editor 완성도에는 반영되지 않는다.
- 메뉴 테스트는 항목 노출뿐 아니라 실제 command type, target cell paragraph, alignment property까지 확인해야 회귀를 막을 수 있다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies paragraph alignment to table text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu runs table cell actions"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu formats selected table cell text"`
- `flutter test test/rhwp_widget_test.dart`
