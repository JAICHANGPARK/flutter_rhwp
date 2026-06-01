# 2026-06-01 native editor table object mode

## 작업한 내용

- page layer tree의 `table` group을 Flutter-native object/control layout으로 인식하도록 했다.
- selected table cell 상태에서 Escape를 누르면 선택된 셀 범위를 표 object 선택으로 올리도록 했다.
- table object 선택 상태에서 Enter 또는 F5를 누르면 첫 번째 셀 선택으로 다시 진입하도록 했다.
- 기존 active cell text edit Escape 흐름은 유지해서 text edit -> cell selection -> table object selection 순서로 빠져나오게 했다.
- README와 CHANGELOG에 table object/cell mode switching 지원을 반영했다.

## 이 작업을 진행한 이유

upstream `web/editor.js`는 표를 object/control로 선택한 뒤 Enter/F5로 cell selection에 들어가고, cell selection에서 Escape로 object selection으로 돌아가는 모드를 갖고 있다. Flutter-native editor도 표 셀 편집 기능은 이미 많지만, 표 전체를 하나의 control로 다루는 모드 전환이 있어야 WebView editor와 작업 흐름이 가까워진다.

## 이 작업을 통해 배울 점

- 표 편집은 셀 단위 편집과 표 control 단위 선택을 분리해야 한다.
- layer tree에서 같은 table control을 셀 layout과 object layout 양쪽으로 해석하면, Flutter overlay가 upstream의 edit mode 전환을 더 자연스럽게 표현할 수 있다.
- Escape/Enter/F5 같은 키는 단일 명령이 아니라 현재 edit mode에 따라 다른 상태 전이를 만들어야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor exits and re-enters table cell edit mode"`
