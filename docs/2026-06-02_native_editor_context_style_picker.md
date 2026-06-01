# 2026-06-02 Native Editor Context Style Picker

## 작업한 내용

- Flutter-native 에디터의 본문 context menu에 `스타일` 항목을 추가했다.
- 표 셀 텍스트 편집 context menu에도 `스타일` 항목을 추가해 active cell paragraph에 문서 스타일을 적용할 수 있게 했다.
- 기존 스타일 picker 다이얼로그를 재사용해 `getStyleList`, `applyStyle`, `applyCellStyle` command 경로를 context menu에서도 검증했다.
- 본문 다중 문단 선택과 표 셀 텍스트 caret 상태에 대한 widget test를 추가했다.

## 이 작업을 진행한 이유

- Flutter-native editor는 toolbar에서 문서 스타일 적용을 지원하지만, 사용자가 실제 편집 중 우클릭 메뉴로 빠르게 스타일을 바꾸는 경로도 필요하다.
- upstream rhwp editor처럼 본문과 표 내부 텍스트 편집 모두에서 문단 스타일 접근성이 같아야 WebView full editor 의존도를 줄일 수 있다.
- 표 셀 텍스트는 body 문단과 다른 command target을 쓰기 때문에 context menu 경로도 별도 회귀 테스트가 필요하다.

## 이 작업을 통해 배울점

- 같은 스타일 picker UI라도 선택 대상에 따라 body는 `applyStyle`, 표 셀 텍스트는 `applyCellStyle`로 분기해야 한다.
- context menu 액션은 메뉴 노출만으로 충분하지 않고, 다이얼로그 선택 이후 실제 command payload까지 고정해야 한다.
- active cell caret 상태는 명시적인 텍스트 범위 선택이 없어도 현재 cell paragraph를 스타일 적용 대상으로 삼을 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies document styles"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies document style to table text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies document styles to paragraphs"`
