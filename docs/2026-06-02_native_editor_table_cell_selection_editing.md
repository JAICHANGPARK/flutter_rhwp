# 2026-06-02 native editor table cell selection editing

## 작업한 내용

- Flutter-native editor에서 표 셀 내부 텍스트 선택이 있을 때 Backspace/Delete가 선택 range를 삭제하도록 연결했다.
- 선택 range가 같은 셀 문단 안에 있으면 `deleteTextInTableCell`, 여러 셀 문단을 걸치면 `deleteRangeInTableCell`을 사용한다.
- 표 셀 내부 텍스트 선택 상태에서 새 텍스트를 입력하면 선택 range를 먼저 삭제하고 같은 위치에 입력 텍스트를 삽입하도록 했다.
- 삭제/입력 뒤에는 selection anchor를 정리하고 collapsed table-cell caret 상태로 되돌린다.

## 이 작업을 진행한 이유

이전 작업에서 표 셀 텍스트 선택 모델과 overlay가 생겼지만, 선택된 텍스트가 실제 편집 명령에 연결되지는 않았다. 편집기에서 선택은 삭제와 교체 입력으로 바로 이어져야 하므로, 이 모델을 실제 rhwp core command 경로에 연결했다.

Flutter-native editor가 WebView 없이 쓰이려면 body text뿐 아니라 table-cell text에서도 선택, 삭제, 입력 교체가 같은 방식으로 동작해야 한다.

## 이 작업을 통해 배울점

- 표 셀 텍스트 선택은 body `RhwpSelectionRange`와 달리 cell paragraph 범위를 따로 정규화해야 한다.
- 같은 셀 문단 삭제와 다중 셀 문단 삭제는 rhwp core command가 다르므로 range 형태에 따라 command를 분기해야 한다.
- 입력 교체는 selection 삭제 결과의 caret 위치를 insert position으로 재사용해야 undo, caret, 후속 입력 흐름이 안정적이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor deletes selected table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor replaces selected table cell text input"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor extends table cell text selection with shift arrows"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor deletes table cell words with keyboard modifiers"`
- `flutter analyze`
- `git diff --check`
