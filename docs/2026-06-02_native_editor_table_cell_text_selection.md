# 2026-06-02 native editor table cell text selection

## 작업한 내용

- `RhwpTableCellSelection`에 table-cell text selection anchor를 추가해 active caret과 selection base를 함께 표현할 수 있게 했다.
- Flutter-native editor에서 표 셀 텍스트 편집 중 `Shift+Left/Right`가 active offset을 이동하면서 text selection range를 유지하도록 변경했다.
- page layer tree의 table-cell text run geometry를 사용해 선택된 텍스트 범위를 overlay로 표시했다.
- 일반 Left/Right 이동은 text selection anchor를 지워 collapsed caret 상태로 돌아가도록 했다.

## 이 작업을 진행한 이유

편집기에서 선택은 삭제, 복사, 서식 적용의 출발점이다. 기존 표 셀 텍스트 편집 모델은 active caret offset만 갖고 있어서 방향키 이동은 가능해도 셀 내부 텍스트 범위를 표현할 수 없었다.

Flutter-native editor가 WebView 없이 실제 편집기로 성장하려면 body text selection과 별도로 table-cell text selection도 모델과 overlay를 가져야 한다. 이번 작업은 그 기반을 만든다.

## 이 작업을 통해 배울점

- 표 셀 텍스트는 body paragraph selection과 같은 section/paragraph만으로 구분할 수 없고, cell index와 cell paragraph context가 필요하다.
- 선택 anchor와 active caret을 분리해두면 Shift+방향키, 이후 삭제/복사/서식 적용을 같은 모델 위에 올릴 수 있다.
- layer tree의 table-cell text run geometry를 직접 사용해야 셀 내부 선택 overlay가 rectangular cell selection과 섞이지 않는다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor extends table cell text selection with shift arrows"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves table cell cursor with arrow keys"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves table cell cursor vertically with arrow keys"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves selected table cells with keyboard"`
- `flutter analyze`
- `git diff --check`
