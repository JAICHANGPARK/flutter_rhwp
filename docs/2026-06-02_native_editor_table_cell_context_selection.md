# 2026-06-02 Native Editor Table Cell Context Selection

## 작업한 내용

- Flutter-native 에디터에서 표 셀 텍스트 선택 범위 안을 secondary click 할 때 기존 선택을 유지하도록 수정했다.
- `_handleSecondaryPointerDown`에 표 셀 텍스트 hit가 현재 선택 범위 안인지 확인하는 분기를 추가했다.
- 본문 텍스트의 context menu 동작처럼, 선택 내부 우클릭은 caret 이동으로 처리하지 않고 context menu가 기존 선택을 대상으로 동작하게 했다.
- 표 셀 텍스트 선택을 우클릭해도 selection overlay와 controller 상태가 유지되는 widget test를 추가했다.

## 이 작업을 진행한 이유

Flutter-native 에디터를 실제 편집기로 쓰려면 우클릭 context menu가 선택 범위를 깨지 않아야 한다. 기존 구현은 표 셀 안에서 텍스트를 선택한 뒤 우클릭하면 `RhwpTableCellSelection.fromCellTextHit`로 selection을 새 caret 상태로 덮어써서, 복사/잘라내기/붙여넣기 같은 메뉴 동작이 사용자가 선택한 범위가 아니라 우클릭 위치 하나만 대상으로 삼을 수 있었다.

## 이 작업을 통해 배울점

- 본문 텍스트와 표 셀 내부 텍스트는 서로 다른 selection 모델을 쓰지만, 사용자가 기대하는 context menu 규칙은 같아야 한다.
- 표 셀 텍스트 selection은 parent paragraph, control index, cell index, cell paragraph, offset을 함께 비교해야 안전하게 범위 포함 여부를 판단할 수 있다.
- Flutter-native 에디터 포팅은 툴바보다 입력/selection/context menu 같은 작은 UX 규칙을 누적해서 맞추는 작업이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor keeps table cell text selection on secondary click"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
