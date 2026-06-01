# 2026-06-02 Native Editor Table Cell Text Paragraph Format

## 작업한 내용

- Flutter-native 에디터에서 표 셀 내부 텍스트 선택 범위가 여러 셀 문단을 포함할 때, 문단 서식 대상을 선택 범위 전체로 확장했다.
- `_tableCellParagraphTargets`가 셀 텍스트 selection range의 시작/끝 cell paragraph를 읽어 각 cell paragraph를 대상으로 반환하도록 수정했다.
- 서식 탭의 문단 정렬이 선택된 셀 텍스트의 모든 포함 문단에 `applyParaFormatInTableCell`을 호출하는 widget test를 추가했다.

## 이 작업을 진행한 이유

기존 구현은 표 셀 텍스트 편집 모드에서 문단 정렬이나 문단 모양을 적용할 때 active cell paragraph 하나만 대상으로 삼았다. 사용자가 셀 내부에서 여러 문단을 선택했다면 문단 서식도 선택 범위의 모든 문단에 적용되어야 실제 WYSIWYG 편집기 동작에 가깝다.

## 이 작업을 통해 배울점

- 표 셀 텍스트 selection은 글자 단위 명령뿐 아니라 문단 단위 명령의 대상 계산에도 사용되어야 한다.
- 문단 서식은 offset 자체를 사용하지 않지만, selection range의 start/end cell paragraph를 통해 적용 대상 문단 목록을 만들 수 있다.
- 같은 helper를 문단 서식과 스타일 적용이 공유하므로 selection 대상 계산을 한 곳에서 고치면 여러 편집 명령의 동작이 함께 개선된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "selected table cell text paragraphs"`
- `flutter test test/rhwp_widget_test.dart --plain-name "paragraph alignment"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
