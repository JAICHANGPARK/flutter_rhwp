# 2026-06-02 Native Editor Table Cell Range Delete Preview

## 작업한 내용

- Flutter-native editor에서 active table-cell text selection을 Delete/Backspace로 지울 때 pending deletion mask를 command 완료 전에 먼저 표시하도록 바꿨다.
- selection이 여러 cell paragraph를 가로지르는 경우 paragraph별 deletion overlay helper를 재사용해서 각 문단 mask를 따로 그리도록 했다.
- Ctrl/Alt word delete의 selection 삭제 경로도 같은 optimistic delete 처리로 맞췄다.

## 이 작업을 진행한 이유

- table-cell cut과 paste replacement는 multi-paragraph pending mask를 지원했지만, keyboard Delete/Backspace selection 삭제는 같은 UX가 빠져 있었다.
- 실제 편집기에서는 사용자가 선택 영역을 잘라내든, 붙여넣기로 대체하든, Delete 키로 지우든 같은 즉시 피드백을 기대한다.
- WebView 없이 Flutter 위젯 에디터를 키우려면 keyboard editing path도 Rust command 완료 전 overlay 피드백을 제공해야 한다.

## 이 작업을 통해 배울점

- selection 삭제는 입력 방식이 달라도 같은 document range와 cell context를 공유하므로 helper를 재사용하는 편이 안정적이다.
- multi-paragraph cell selection은 하나의 overlay로 처리하지 않고 cell paragraph별 overlay로 나눠야 layer-tree hit geometry와 잘 맞는다.
- keyboard delete path도 visible busy를 피하고 deferred refresh를 쓰면 사용자가 보기에는 셀 내부 텍스트가 즉시 지워진 것처럼 반응한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews multi paragraph table cell delete"`
- `flutter test test/rhwp_widget_test.dart --plain-name "previews multi paragraph table cell cut"`
- `flutter test test/rhwp_widget_test.dart --plain-name "deletes table cell words"`
- `flutter test test/rhwp_widget_test.dart --plain-name "clears selected table cell text"`
- `flutter analyze`
- `git diff --check`
