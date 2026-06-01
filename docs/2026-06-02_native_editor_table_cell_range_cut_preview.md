# 2026-06-02 Native Editor Table Cell Range Cut Preview

## 작업한 내용

- Flutter-native editor에서 active table-cell text selection이 여러 cell paragraph를 가로지를 때 pending deletion mask를 paragraph별로 분해해 표시하도록 했다.
- multi-paragraph table-cell `Ctrl+X` cut에서 `deleteRangeInTableCell` command가 완료되기 전에도 각 cell paragraph의 삭제 영역과 collapsed cell caret가 먼저 보이도록 했다.
- table-cell multiline paste replacement도 같은 paragraph별 deletion overlay helper를 사용하게 정리했다.

## 이 작업을 진행한 이유

- 단일 cell paragraph cut은 pending deletion mask를 표시했지만, 여러 cell paragraph를 가로지르는 selection은 하나의 cell context로 표현할 수 없어 preview가 빠질 수 있었다.
- upstream web editor 수준의 table-cell editing UX를 Flutter 위젯으로 구현하려면 셀 내부 문단 선택도 body multi-paragraph selection처럼 즉시 피드백을 제공해야 한다.
- Rust core가 실제 문서 구조 변경의 source of truth를 유지하되, Flutter overlay는 command 완료 전 사용자 피드백을 더 촘촘하게 담당해야 한다.

## 이 작업을 통해 배울점

- `RhwpLayerTree.selectionRectsForRange`는 cell context 단위로 필터링되므로 multi-paragraph cell selection은 여러 pending overlay로 나누는 방식이 맞다.
- visible text segment가 있는 cell paragraph는 layer-tree segment 끝 offset을 사용하고, 보이지 않는 paragraph는 Rust `cellParagraphLength` fallback으로 mask 범위를 계산할 수 있다.
- table-cell cut과 paste replacement가 같은 pending deletion overlay helper를 공유하면 입력 UX가 일관되고 테스트 범위도 명확해진다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews multi paragraph table cell cut"`
- `flutter test test/rhwp_widget_test.dart --plain-name "previews table cell text cut"`
- `flutter test test/rhwp_widget_test.dart --plain-name "previews multiline table cell paste"`
- `flutter test test/rhwp_widget_test.dart --plain-name "copies multi paragraph selected table cell text range"`
- `flutter analyze`
- `git diff --check`
