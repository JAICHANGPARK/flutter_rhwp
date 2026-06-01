# 2026-06-02 Native Editor Table Context Para Shape Dialog

## 작업한 내용

- Flutter-native 에디터의 표 셀 텍스트 context menu에서 `문단 모양` 다이얼로그를 여는 경로를 테스트로 고정했다.
- 다이얼로그에서 줄 간격, 들여쓰기, 좌우 여백, 문단 앞/뒤 간격 값을 입력한 뒤 active cell paragraph에 적용되는지 검증했다.
- 적용 결과가 `applyParaFormatInTableCell` command로 나가고, 대상 section/paragraph/control/cell/cellParagraph와 paragraph properties가 정확한지 확인했다.

## 이 작업을 진행한 이유

- 직전 작업에서 표 셀 텍스트 context menu에 문단 서식 항목을 추가했지만, 직접 정렬 버튼뿐 아니라 다이얼로그 기반 문단 속성 적용도 검증되어야 한다.
- Flutter-native editor가 WebView editor를 대체하려면 표 셀 내부에서도 줄 간격, 여백, 들여쓰기 같은 문단 속성 편집이 안정적으로 동작해야 한다.
- `문단 모양`은 여러 값을 한 번에 적용하는 경로라 단순 정렬보다 command payload 회귀 위험이 크다.

## 이 작업을 통해 배울점

- 표 셀 문단 서식은 body 문단 서식과 같은 dialog UI를 쓰더라도 command target은 `applyParaFormatInTableCell`이어야 한다.
- context menu 테스트는 메뉴 노출만 확인하면 부족하다. 다이얼로그 입력값이 core command의 `properties`로 정확히 전달되는지 확인해야 한다.
- active cell caret 상태에서는 선택 영역 없이도 현재 cell paragraph를 paragraph-format target으로 삼을 수 있어야 한다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies paragraph shape to table text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies paragraph alignment to table text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies paragraph shape dialog values"`
- `flutter test test/rhwp_widget_test.dart`
