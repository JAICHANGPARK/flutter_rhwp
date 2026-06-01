# 2026-06-02 Native Editor Table Context Character Shape Pending

## 작업한 내용

- Flutter-native 에디터의 표 셀 텍스트 caret에서 context menu `글자 모양` 다이얼로그를 여는 경로를 테스트로 고정했다.
- 다이얼로그에서 font size와 bold를 설정해도 즉시 core command가 나가지 않고 pending character format으로 유지되는지 확인했다.
- 이후 표 셀에 텍스트를 입력하면 `insertTextInTableCell` 다음에 `applyCharFormatInTableCell`이 붙고, 입력된 글자 범위에 다이얼로그 값이 적용되는지 검증했다.

## 이 작업을 진행한 이유

- 직전 작업에서 표 셀 caret context menu에 문자 서식 그룹을 열었지만, 단순 토글뿐 아니라 `글자 모양` 다이얼로그 기반 서식도 같은 pending 입력 모델을 타야 한다.
- WebView 기반 editor를 Flutter-native editor로 대체하려면 body와 table-cell text editing 모두에서 toolbar, context menu, dialog가 동일한 편집 semantics를 가져야 한다.
- 다이얼로그는 여러 서식 값을 한 번에 바꾸므로, 단일 `굵게` 토글보다 pending format 회귀 위험이 크다.

## 이 작업을 통해 배울점

- 표 셀 텍스트 입력의 pending format은 `insertTextInTableCell` 뒤에 적용되는 후속 `applyCharFormatInTableCell` command로 검증하는 것이 가장 명확하다.
- context menu에서 다이얼로그를 열어도 선택 영역이 없는 caret 상태에서는 문서를 즉시 수정하지 않아야 한다.
- 테스트는 단순히 메뉴가 열리는지보다 command 순서와 적용 범위를 확인해야 native editor의 실제 편집 모델을 보호할 수 있다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu character shape sets pending table format"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies pending format to table input"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu formats selected table cell text"`
- `flutter test test/rhwp_widget_test.dart`
