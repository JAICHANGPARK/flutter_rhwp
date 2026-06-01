# 2026-06-02 native editor table cell page navigation

## 작업한 내용

- Flutter-native editor에서 표 셀 텍스트 편집 중 `PageUp`/`PageDown`이 body cursor가 아니라 활성 셀 내부 텍스트 cursor를 움직이도록 했다.
- 이동 대상은 page-layer text geometry에서 같은 table cell context를 가진 run만 대상으로 찾는다.
- 같은 셀/문단/offset이 여러 페이지에 반복될 수 있으므로 현재 viewer page를 먼저 탐색하도록 table-cell run lookup 순서를 보정했다.
- `Shift+PageDown`은 table-cell text selection anchor를 유지하며 다음 페이지의 셀 텍스트 위치까지 선택 범위를 확장한다.

## 이 작업을 진행한 이유

기존 PageUp/PageDown은 표 셀 텍스트 편집 중에도 body page navigation 경로를 탔다. 표 셀 안에서 편집 중인 사용자는 페이지 이동 키를 눌러도 body selection이 아니라 현재 셀 텍스트의 caret/selection이 이동하기를 기대한다.

Flutter-native editor가 WebView 없이 실제 편집기로 성장하려면 키보드 navigation이 현재 편집 컨텍스트를 일관되게 따라야 한다.

## 이 작업을 통해 배울점

- HWP 표 셀은 페이지가 나뉘어도 같은 cell context와 offset이 반복될 수 있으므로, run lookup에서 현재 page 우선순위가 중요하다.
- body text page navigation과 table-cell text page navigation은 비슷하지만 hit-test 대상 run 집합이 달라야 한다.
- Shift 확장을 기존 `_tableCellSelectionWithTextCaret`로 처리하면 PageDown 선택도 복사/삭제/붙여넣기 selection 모델과 바로 호환된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text cursor with page keys"`
- `flutter test test/rhwp_widget_test.dart --plain-name "page up and page down"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
