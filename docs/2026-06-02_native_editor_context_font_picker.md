# 2026-06-02 Native Editor Context Font Picker

## 작업한 내용

- Flutter-native 에디터의 본문 context menu에 `글꼴/크기` 항목을 추가했다.
- 표 셀 텍스트 편집 context menu에도 같은 `글꼴/크기` 항목을 추가했다.
- 글꼴 family와 자주 쓰는 글자 크기를 선택하는 스크롤 가능한 picker dialog를 만들었다.
- 본문 선택 영역의 글꼴 적용과 표 셀 텍스트 선택 영역의 글자 크기 적용 command payload를 테스트했다.

## 이 작업을 진행한 이유

- upstream web editor의 기본 서식 흐름에는 글꼴과 크기 선택이 포함되어 있어 Flutter-native editor에서도 같은 편집 접근성이 필요했다.
- context menu에서 바로 글꼴/크기를 바꿀 수 있으면 전체 글자 모양 다이얼로그를 열지 않고도 자주 쓰는 서식을 빠르게 적용할 수 있다.
- 본문과 표 셀 텍스트가 서로 다른 rhwp command 경로를 쓰기 때문에, 같은 UI 동작이 두 편집 컨텍스트에서 모두 맞게 분기되는지 확인해야 했다.

## 이 작업을 통해 배울점

- 글꼴 목록은 화면 높이에 따라 쉽게 overflow가 나므로 picker content는 스크롤 가능하게 만드는 것이 안전하다.
- body 선택 영역은 `applyCharFormatRange`, 표 셀 텍스트 선택은 `applyCharFormatInTableCell`로 분기해야 한다.
- context menu 항목이 늘어나면 기존 테스트도 항목을 보이게 스크롤한 뒤 탭하도록 갱신해야 한다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies font family"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies font size to table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu character shape sets pending format at caret"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu character shape sets pending table format"`
- `flutter test test/rhwp_widget_test.dart`
