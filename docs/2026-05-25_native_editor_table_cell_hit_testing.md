# Native Editor Table Cell Hit Testing

## 작업한 내용

- vendored rhwp page layer tree JSON의 `table` group에 `sectionIndex`, `paraIndex`, `controlIndex`를 함께 내보내도록 했다.
- Dart `RhwpLayerTree`에 `RhwpTableCellLayout`, `tableCells`, `tableCellForPoint()`를 추가했다.
- `RhwpNativeEditor` page overlay가 렌더된 표 셀을 탭하면 table edit context를 자동으로 채우도록 연결했다.
- 표 셀 layer tree parsing unit test와 셀 탭 후 `splitTableCell` command가 선택된 table context로 나가는 widget test를 추가했다.
- Rust facade test에서 표 삽입 후 page layer tree가 table/tableCell geometry와 table context를 포함하는지 검증했다.

## 이 작업을 진행한 이유

숫자 입력만으로 table paragraph, control index, row, column을 맞추는 방식은 실제 에디터 UX로 보기 어렵다.
Flutter-native editor가 WebView fallback을 대체하려면 렌더된 문서 위에서 표 셀을 직접 선택하고, 그 선택이 곧바로 표 편집 명령의 기준점이 되어야 한다.
이번 작업은 셀 선택 UX의 첫 단계로, rhwp core가 가진 page layer tree geometry를 Flutter editor 상태와 연결했다.

## 이 작업을 통해 배울점

- table cell 자체에는 row/column/span이 있지만, 편집 command에는 parent table의 section/paragraph/control index도 필요하다.
- 따라서 layer tree JSON에서 table group의 model context와 tableCell group의 geometry context를 함께 읽어야 한다.
- Flutter overlay 좌표는 실제 위젯 크기로 스케일되므로 hit testing 전 page 좌표로 되돌리는 변환이 필요하다.
- 다음 단계는 선택된 셀 highlight, multi-cell drag selection, nested table context 처리다.

## 검증

- `dart format lib/src/rhwp_layer_tree.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "page layer tree model maps table cell hit context"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor taps table cell to set table edit context"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
