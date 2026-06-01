# 2026-06-02 Native Editor Context Line Spacing

## 작업한 내용

- Flutter-native 에디터의 본문 context menu에 `줄 간격` 항목을 추가했다.
- 표 셀 텍스트 편집 context menu에도 `줄 간격` 항목을 추가했다.
- `100%`부터 `300%`까지 기존 toolbar preset 목록을 칩형 다이얼로그로 제공하도록 했다.
- 선택한 preset을 body 문단 범위에는 `applyParaFormatRange`, 표 셀 텍스트에는 `applyParaFormatInTableCell` command로 적용하는 테스트를 추가했다.

## 이 작업을 진행한 이유

- 줄 간격은 toolbar에서 이미 지원되지만, 실제 편집 중에는 우클릭 context menu에서 빠르게 바꾸는 흐름이 필요하다.
- Flutter-native editor가 WebView full editor를 대체하려면 본문과 표 셀 내부 텍스트 모두에서 자주 쓰는 문단 서식 기능을 같은 접근성으로 제공해야 한다.
- 표 셀 텍스트는 body 문단과 command target이 다르므로 context menu 경로도 별도 검증이 필요하다.

## 이 작업을 통해 배울점

- 같은 줄 간격 UI라도 body 선택 범위는 문단 range command, 표 셀 텍스트 caret은 cell paragraph command로 분기해야 한다.
- preset 선택 UI는 lazy list보다 한눈에 보이는 chip grid가 테스트 안정성과 실제 사용성 모두에 유리하다.
- context menu 기능은 command bridge를 새로 만들기보다 기존 paragraph format 경로를 재사용하면 플랫폼 공통성을 유지할 수 있다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies line spacing preset"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies line spacing to table text"`
- `flutter test test/rhwp_widget_test.dart`
