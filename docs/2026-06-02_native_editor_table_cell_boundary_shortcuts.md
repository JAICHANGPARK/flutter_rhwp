# 2026-06-02 native editor table cell boundary shortcuts

## 작업한 내용

- Flutter-native editor에서 표 셀 텍스트 편집 중 `Ctrl+Home`/`Cmd+Home`이 문서 시작이 아니라 활성 셀의 첫 cell paragraph offset 0으로 이동하도록 했다.
- `Ctrl+End`/`Cmd+End`는 활성 셀의 마지막 cell paragraph 끝으로 이동하도록 했다.
- `Shift+Ctrl+End`처럼 Shift와 함께 누르면 기존 table-cell text selection anchor를 사용해 활성 셀 끝까지 선택 범위를 확장한다.
- plain Home/End 문단 이동 경로는 유지하고, shortcut Home/End만 활성 셀 boundary로 분기했다.

## 이 작업을 진행한 이유

표 셀 내부 텍스트 편집 상태에서도 shortcut Home/End가 먼저 전역 document boundary handler에 잡혀 body cursor를 움직일 수 있었다. Flutter-native editor에서는 현재 편집 컨텍스트가 표 셀이면 문서 전체가 아니라 셀 내부 텍스트 범위 안에서 이동해야 한다.

이 동작이 맞춰져야 이후 삭제, 복사, 붙여넣기, select-all 같은 table-cell text selection 기능들이 키보드 조합에서도 일관되게 동작한다.

## 이 작업을 통해 배울점

- shortcut key routing은 일반 navigation보다 먼저 처리되므로 table-cell edit mode 분기를 shortcut switch 안에도 둬야 한다.
- 셀 끝 위치는 page-layer text run을 우선 사용하고, 필요하면 core cell paragraph length로 fallback하는 구조가 기존 Home/End와 잘 맞는다.
- Shift 확장은 `_tableCellSelectionWithTextCaret`을 재사용하면 selection anchor와 collapsed 상태 정리를 한곳에서 유지할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "cell boundaries with shortcuts"`
- `flutter test test/rhwp_widget_test.dart --plain-name "home and end"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
