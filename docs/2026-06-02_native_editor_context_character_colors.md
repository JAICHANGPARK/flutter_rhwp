# 2026-06-02 Native Editor Context Character Colors

## 작업한 내용

- Flutter-native 에디터의 본문 context menu에 `글자 색상` 항목을 추가했다.
- 표 셀 텍스트 편집 context menu에도 같은 `글자 색상` 항목을 추가했다.
- toolbar에서 쓰던 글자 색/배경 색 swatch 목록을 재사용하는 칩형 다이얼로그를 만들었다.
- 본문 선택 영역의 글자 색 적용과 표 셀 텍스트 선택 영역의 배경 색 적용 command payload를 테스트했다.

## 이 작업을 진행한 이유

- upstream web editor의 format toolbar 기능을 Flutter-native editor로 옮기는 과정에서 색상 서식은 toolbar에만 있어 context editing 흐름이 부족했다.
- 글자 색과 배경 색은 자주 쓰는 글자 서식이므로, 글자 모양 다이얼로그를 열지 않고도 context menu에서 바로 접근할 수 있어야 한다.
- context menu 자체가 길어지지 않도록 `글자 색상` 하나의 항목에서 글자 색/배경 색 swatch를 함께 제공했다.

## 이 작업을 통해 배울점

- 같은 swatch 목록을 toolbar와 context picker에서 공유하면 색상 선택지가 서로 달라지는 회귀를 줄일 수 있다.
- body 선택 영역은 `applyCharFormatRange`, 표 셀 텍스트 선택은 `applyCharFormatInTableCell`로 분기해야 한다.
- context menu에는 자주 쓰는 진입점만 두고, 세부 선택은 작은 picker dialog로 옮기는 편이 화면 크기와 테스트 안정성에 유리하다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies character colors"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies colors to table cell text"`
- `flutter test test/rhwp_widget_test.dart`
