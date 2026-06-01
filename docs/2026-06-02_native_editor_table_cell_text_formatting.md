# 2026-06-02 Native Editor Table Cell Text Formatting

## 작업한 내용

- Flutter-native 에디터에서 표 셀 내부 텍스트 선택 범위에 글자 서식을 적용하도록 수정했다.
- 선택된 셀 텍스트가 여러 셀 문단에 걸쳐 있을 때 각 셀 문단별 `applyCharFormatInTableCell` range로 나누어 rhwp core에 전달한다.
- 표 셀 텍스트 선택 상태의 context menu에 굵게, 기울임, 밑줄, 취소선, 글자 모양 항목을 추가했다.
- 우클릭 메뉴에서 굵게를 선택하면 기존 표 셀 텍스트 selection을 유지한 채 선택 범위에만 서식이 적용되는 widget test를 추가했다.

## 이 작업을 진행한 이유

기존 구현은 표 셀 텍스트 편집 모드에서 글자 서식 버튼을 누르면 선택 범위가 있어도 실제 문서 range를 수정하지 않고 다음 입력에 사용할 pending format만 갱신했다. Flutter-native 에디터가 WebView fallback을 대체하려면 선택된 셀 내부 글자에 바로 서식을 적용할 수 있어야 한다.

## 이 작업을 통해 배울점

- 표 셀 selection과 표 셀 내부 text selection은 같은 `RhwpTableCellSelection`을 공유하지만, 서식 적용 시에는 셀 문단 단위 range로 변환해야 한다.
- 선택 범위가 여러 셀 문단을 가로지르면 시작 문단, 중간 문단, 끝 문단의 start/end offset 계산 규칙이 다르다.
- context menu는 selection을 보존하는 것만으로 충분하지 않고, 현재 selection 모델에 맞는 명령 항목까지 노출해야 실제 편집 UX가 완성된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu formats selected table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
