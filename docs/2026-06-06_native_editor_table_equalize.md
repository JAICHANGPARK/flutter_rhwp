# Native editor table cell equalize

## 작업한 내용

- Flutter-native table ribbon에 `Equalize cell heights`, `Equalize cell widths` 버튼을 추가했다.
- 선택된 table-cell 범위의 `cellProperties`를 셀별로 읽고, 가장 큰 width 또는 height에 맞춰 `resizeTableCells` delta를 생성하도록 구현했다.
- 선택 셀이 이미 같은 크기이면 undo snapshot, dirty state, document refresh를 만들지 않고 editor focus만 되돌리도록 처리했다.
- widget test에서 서로 다른 셀 크기를 가진 fake session을 사용해 width/height equalize command payload를 검증했다.
- `CHANGELOG.md`, `docs/TODO.md`, `docs/API_SPEC.md`, `docs/NATIVE_EDITOR_PARITY.md`에 반영했다.

## 이 작업을 진행한 이유

upstream Web editor의 표 메뉴에는 셀 높이와 너비를 같게 만드는 기능이 있다. Flutter-native editor parity 문서에서는 이 기능이 미구현 상태였고, 이미 `resizeTableCells` command가 Dart/Rust API에 노출되어 있었기 때문에 Rust core를 새로 흔들지 않고 Flutter widget 리본에서 바로 연결할 수 있었다.

선택 범위의 최대 크기에 맞추는 정책을 쓴 이유는 내용 잘림 위험을 줄이고, 사용자가 선택한 여러 셀을 한 번에 정렬하는 동작으로 예측하기 쉽기 때문이다.

## 이 작업을 통해 배울점

- page layer tree의 셀 bounds는 화면/page 좌표이고, HWP cell width/height command 단위와 직접 같다고 보면 안 된다.
- 크기 변경 command를 만들 때는 rendered bounds가 아니라 `cellProperties`에서 core 단위 값을 읽어 delta를 계산해야 한다.
- Flutter-native editor parity는 새 Rust API가 필요한 기능과 기존 command를 UI로 연결하면 되는 기능을 분리해서 처리하는 것이 빠르다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor equalizes selected table cell sizes"
flutter analyze
```
