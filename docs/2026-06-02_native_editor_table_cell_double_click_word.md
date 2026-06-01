# 2026-06-02 native editor table cell double click word

## 작업한 내용

- Flutter-native editor에서 표 셀 내부 텍스트를 더블클릭하면 해당 단어가 선택되도록 했다.
- 기존 본문 더블클릭 단어 선택의 word-boundary 계산을 공용 helper로 분리하고, 표 셀 hit는 `RhwpTableCellSelection`의 text selection 범위로 변환했다.
- 문서 편집으로 page layer가 갱신되면 이전 클릭 시퀀스를 초기화해서, 편집 전후의 빠른 클릭이 잘못된 더블클릭으로 이어지지 않도록 했다.

## 이 작업을 진행한 이유

upstream 웹 에디터는 `dblclick` 이벤트에서 text run을 기준으로 단어 선택을 처리한다. Flutter-native editor도 본문에는 같은 동작이 있었지만 표 셀 텍스트 hit는 더블클릭 카운터에서 제외되어, 셀 내부에서는 caret 이동만 가능했다.

표 셀 안에서 복사, 삭제, 붙여넣기, 검색 교체가 모두 text selection 모델에 연결된 만큼, 마우스 기반 단어 선택도 같은 모델로 들어와야 실제 편집기로 쓰기 편하다.

## 이 작업을 통해 배울점

- 표 셀 텍스트는 body selection이 아니라 table-cell selection state로 표현해야 후속 편집 명령과 연결된다.
- 더블클릭 판정은 단순 시간/거리뿐 아니라 문서 layer 갱신 시점에도 초기화해야 편집 후 클릭이 이전 클릭과 섞이지 않는다.
- 본문과 표 셀은 selection 타입이 다르지만 word-boundary 계산은 page-layer text run 기준으로 공유할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "table cell word on double click"`
- `flutter test test/rhwp_widget_test.dart --plain-name "double click"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
