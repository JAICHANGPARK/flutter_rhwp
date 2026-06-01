# Flutter Native Editor Table Range Split

## 작업한 내용

- `RhwpCommand`/`RhwpDocument`에 `splitTableCellsInRange` 명령을 추가했다.
- Rust facade에서 vendored rhwp core의 `split_table_cells_in_range_native` API를 호출하도록 연결했다.
- `RhwpNativeEditor`의 기존 `Split cell into` 다이얼로그를 확장했다.
  - 선택 범위가 실제로 여러 model cell을 포함하면 `splitTableCellsInRange`를 호출한다.
  - 단일 병합 셀처럼 row span 때문에 좌표상 범위처럼 보이는 경우는 기존 `splitTableCellInto`를 유지한다.
- Dart command serialization, document convenience API, Flutter widget flow, Rust command path 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream rhwp core에는 표 셀 하나가 아니라 선택된 셀 범위를 한 번에 N x M 격자로 나누는 API가 있다. Flutter-native editor가 HWP 스타일 편집기로 가려면, 단일 셀 편집뿐 아니라 선택 범위 단위의 표 편집도 같은 UI 흐름에서 처리해야 한다.

이번 작업은 Flutter 쪽에서 직접 표 구조를 변경하지 않고, 선택 상태만 해석한 뒤 Rust core 명령으로 넘긴다. 이 구조는 WebView fallback과 별도로 Flutter 위젯 에디터가 점진적으로 upstream editor 기능을 따라가는 방향과 맞다.

## 이 작업을 통해 배울 점

- 표 셀 선택은 화면 좌표의 사각형과 문서 모델의 cell index가 항상 1:1로 대응하지 않는다.
- row span/column span이 있는 셀은 `startRow`와 `endRow`가 달라도 단일 model cell일 수 있다.
- Flutter-native editor에서는 범위 판단을 layer tree의 `modelCellIndex` 기준으로 해야 문서 모델 명령을 정확히 선택할 수 있다.
