# 2026-06-02 Native Editor Table Context Pending Character Format

## 작업한 내용

- Flutter-native 에디터에서 표 셀 텍스트 편집 caret 상태일 때 context menu에 `굵게`, `기울임`, `밑줄`, `취소선`, `글자 모양`을 노출했다.
- 표 셀 텍스트가 선택된 경우뿐 아니라 선택 영역이 없는 active cell caret에서도 문자 서식을 예약할 수 있게 했다.
- 표 셀 전체 선택/행/열 작업 context menu에는 문자 서식 그룹을 추가하지 않도록 `isTextEditing`과 `activeCellIndex` 조건으로 범위를 제한했다.
- context menu에서 `굵게`를 예약한 뒤 표 셀에 입력한 텍스트에 `applyCharFormatInTableCell`이 따라붙는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

- body caret에서는 context menu pending character format이 가능해졌지만, 표 셀 텍스트 편집 caret에서는 여전히 선택된 텍스트가 있어야만 context menu 서식을 사용할 수 있었다.
- 실제 문서 편집에서는 표 셀 내부에 새 텍스트를 입력하기 전에 굵게/글자 모양을 예약하는 흐름이 자주 필요하다.
- Flutter-native 에디터가 WebView fallback을 대체하려면 body와 table-cell text editing이 같은 입력/서식 모델을 공유해야 한다.

## 이 작업을 통해 배울점

- 표 셀 context menu는 셀 작업과 텍스트 작업이 같은 표면을 공유하므로, 메뉴 노출 조건을 넓힐 때 UX 범위를 정확히 제한해야 한다.
- `hasTextSelection`만 기준으로 삼으면 collapsed caret의 pending format 경로가 사용자에게 닫힌다. 반대로 `tableCellSelection != null`만 기준으로 삼으면 셀 작업 메뉴가 불필요하게 커진다.
- table-cell text editing은 `isTextEditing`과 `activeCellIndex`를 함께 확인해야 입력 서식 대상이 명확하다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies pending format to table input"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu runs table cell actions"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu formats selected table cell text"`
- `flutter test test/rhwp_widget_test.dart`
