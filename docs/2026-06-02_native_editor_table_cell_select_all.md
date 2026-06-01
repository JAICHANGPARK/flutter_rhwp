# 2026-06-02 native editor table cell select all

## 작업한 내용

- Flutter-native editor에서 표 셀 텍스트 편집 중 `Ctrl+A`/`Cmd+A`를 누르면 활성 셀 내부 텍스트 전체를 선택하도록 했다.
- 선택 범위는 cell paragraph 0, offset 0에서 활성 셀의 마지막 visible text run 끝까지 잡는다.
- body selection은 collapsed 상태로 유지하고, table-cell selection의 text anchor만 설정해 기존 삭제/복사/붙여넣기 경로를 그대로 재사용하게 했다.
- 활성 셀에 여러 cell paragraph가 있는 경우 마지막 cell paragraph 끝까지 선택되는지 위젯 테스트로 검증했다.

## 이 작업을 진행한 이유

기존 select-all은 본문 text run만 대상으로 삼아서 표 셀 내부 텍스트를 편집 중이어도 body 전체 선택 경로를 탔다. Flutter-native editor가 실제 편집기로 쓰이려면 caret이 있는 편집 컨텍스트에 맞게 선택 범위가 만들어져야 한다.

표 셀 내부 텍스트 선택, 삭제, 복사, 붙여넣기 경로가 이미 연결되었으므로 select-all도 같은 selection model에 붙이는 것이 자연스럽다.

## 이 작업을 통해 배울점

- select-all은 단순히 문서 전체 선택 하나로 끝나지 않고 현재 편집 컨텍스트(body, table cell, object)에 따라 다른 selection model을 선택해야 한다.
- table-cell text selection은 body `RhwpSelectionRange`가 아니라 `RhwpTableCellSelection`의 `selectionBaseCellParagraph`와 `selectionBaseOffset`으로 표현해야 한다.
- page-layer text geometry를 활용하면 core command 없이도 visible cell text의 끝 위치를 빠르게 구할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "selects all active table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "select all"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
