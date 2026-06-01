# 2026-06-02 Native Editor Context Character Effects

## 작업한 내용

- Flutter-native 에디터의 본문 context menu에 `글자 효과` 항목을 추가했다.
- 표 셀 텍스트 편집 context menu에도 같은 `글자 효과` 항목을 추가했다.
- `위첨자`, `아래첨자`, `양각`, `음각`을 선택하는 칩형 다이얼로그를 만들었다.
- 본문 선택 영역과 표 셀 텍스트 선택 영역에서 각각 `applyCharFormatRange`, `applyCharFormatInTableCell` command payload가 나가는지 테스트했다.

## 이 작업을 진행한 이유

- upstream web editor의 format toolbar에는 글자 효과가 있지만, Flutter-native editor의 context menu에서는 굵게/기울임/밑줄/취소선까지만 바로 접근할 수 있었다.
- 글자 효과는 글자 모양 다이얼로그에서도 설정할 수 있지만, 실제 편집 중에는 context menu에서 빠르게 선택하는 경로가 필요하다.
- 효과 4개를 context menu에 직접 늘어놓으면 메뉴가 화면 밖으로 밀릴 수 있어, `글자 효과` 한 항목과 칩형 다이얼로그로 구성했다.

## 이 작업을 통해 배울점

- context menu가 길어질 때는 항목을 계속 추가하기보다 작은 picker dialog로 묶는 편이 테스트 안정성과 실제 사용성 모두에 낫다.
- body 선택 영역은 `applyCharFormatRange`, 표 셀 텍스트 선택은 `applyCharFormatInTableCell`로 분기해야 한다.
- 위첨자/아래첨자, 양각/음각은 상호 배타적인 효과라 기존 `_toggleCharFormat` 경로를 재사용해야 상태 토글 규칙을 유지할 수 있다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies character effects"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies effects to table cell text"`
- `flutter test test/rhwp_widget_test.dart`
