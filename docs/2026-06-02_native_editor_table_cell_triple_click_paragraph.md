# 2026-06-02 native editor table cell triple click paragraph

## 작업한 내용

- Flutter-native editor에서 표 셀 내부 텍스트를 트리플클릭하면 해당 셀 문단 전체가 선택되도록 했다.
- 같은 table cell context와 같은 `cellParagraph`를 가진 page-layer text run들을 모아 선택 시작/끝 offset을 계산한다.
- 본문 트리플클릭 문단 선택과 표 셀 트리플클릭 문단 선택이 각자의 selection model로 분리되어 동작하도록 했다.

## 이 작업을 진행한 이유

본문 텍스트는 이미 트리플클릭으로 문단 선택이 가능했지만, 표 셀 내부 텍스트는 세 번째 클릭이 별도 처리 없이 caret 이동으로 돌아갈 수 있었다. upstream 웹 에디터처럼 마우스 기반 선택 동작을 편집 컨텍스트에 맞추려면 표 셀 안에서도 단어 선택 다음 단계인 문단 선택이 필요하다.

표 셀 내부 문단 선택이 가능해지면 복사, 삭제, 붙여넣기, 서식 적용 같은 후속 명령이 더 자연스럽게 이어진다.

## 이 작업을 통해 배울점

- 표 셀 안의 문단 선택은 body paragraph selection이 아니라 `RhwpTableCellSelection`의 text range로 표현해야 한다.
- page-layer text run의 cell context를 기준으로 범위를 계산하면 WebView 없이도 upstream 웹 에디터의 hit-test 흐름을 Flutter에서 재구성할 수 있다.
- 더블클릭과 트리플클릭은 같은 click sequence를 공유하므로, 표 셀 branch에서도 click count를 명확히 소비해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "table cell paragraph on triple click"`
- `flutter test test/rhwp_widget_test.dart --plain-name "triple click"`
- `flutter test test/rhwp_widget_test.dart --plain-name "double click"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
