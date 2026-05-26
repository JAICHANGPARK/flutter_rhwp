# Native Editor Split Cell Into Grid

## 작업한 내용

- `RhwpCommand.splitTableCellInto`와 `RhwpDocument.splitTableCellInto()` API를 추가했다.
- Rust command facade에서 `splitTableCellInto` JSON command를 rhwp core의 `split_table_cell_into_native`로 라우팅했다.
- Flutter-native editor 표 리본에 `Split cell into` 버튼과 `셀 나누기` 다이얼로그를 추가했다.
- 선택된 표 셀을 기준으로 행/열 수, 행 높이 균등 여부, 선 병합 여부를 받아 N행 x M열 분할 command를 실행하도록 연결했다.
- Dart command serialization, document wrapper, Flutter widget flow, Rust facade 테스트를 추가했다.

## 이 작업을 진행한 이유

기존 Flutter-native editor는 셀 병합 해제에 가까운 단순 `splitTableCell`만 제공했다. 실제 HWP 에디터에 가까워지려면 셀을 사용자가 지정한 행/열 격자로 나누는 작업이 필요하고, upstream rhwp core에는 이미 해당 기능이 있으므로 Flutter UI와 FRB command surface에 노출하는 것이 맞다.

## 이 작업을 통해 배울점

- upstream core에 이미 있는 편집 기능은 WebView를 거치지 않고 Dart command와 Rust facade만 확장해 Flutter-native UI에서 직접 사용할 수 있다.
- 표 편집 UX는 선택된 셀 hit-test 결과를 command 인자로 재사용하면 별도 좌표 변환 없이 안정적으로 이어 붙일 수 있다.
- 단순 버튼과 고급 다이얼로그를 분리하면 기존 빠른 동작을 유지하면서 실제 에디터 수준의 세부 제어를 단계적으로 추가할 수 있다.
