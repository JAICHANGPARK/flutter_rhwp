# Native Editor Table Cell Drag Selection

## 작업한 내용

- `RhwpTableCellSelection.fromCells()`를 추가해 두 표 셀 사이의 직사각형 cell range를 만들 수 있게 했다.
- Flutter-native page overlay가 표 셀에서 시작한 pointer drag를 텍스트 selection과 분리해서 처리하도록 했다.
- 같은 표 안에서 드래그하면 table edit context의 start/end row/column이 드래그 범위로 갱신되도록 했다.
- 선택 범위에 포함된 여러 셀을 page overlay에서 각각 highlight하도록 유지했다.
- drag selection 후 `Merge cells` 명령이 선택된 multi-cell range로 나가는 widget test를 추가했다.

## 이 작업을 진행한 이유

표 편집에서 셀 병합은 단일 셀 선택만으로는 의미가 약하다.
사용자가 실제 문서 위에서 시작 셀과 끝 셀을 드래그해 범위를 만들고, 그 범위가 곧바로 merge/split 같은 table command context가 되어야 한다.
이번 작업은 WebView 없이 Flutter 위젯만으로 표 셀 선택 UX를 에디터답게 만드는 다음 단계다.

## 이 작업을 통해 배울점

- 표 셀 drag는 텍스트 drag selection과 같은 pointer stream을 쓰지만 상태 모델은 분리해야 한다.
- 셀 range는 row/column 모델 좌표로 저장하고, 화면 표시용 rect는 현재 page layer tree에서 다시 계산하는 편이 안정적이다.
- 병합된 셀처럼 rowSpan/colSpan이 있는 경우 endRow/endColumn은 cell span을 포함해서 계산해야 한다.
- 다음 단계는 Shift/command 확장 선택, drag handle, 셀 속성 dialog, border/background command 연결이다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor drags table cells to extend table edit range"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor taps table cell to set table edit context"`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
