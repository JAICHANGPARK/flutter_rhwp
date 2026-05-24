# 2026-05-25 Editor Caret Selection Overlay

## 작업한 내용

- `RhwpCursorPosition`에 위치 비교와 값 동등성 처리를 추가했다.
- `RhwpSelectionRange`를 추가해서 collapsed cursor와 expanded selection 상태를 하나의 controller 상태로 관리하도록 했다.
- `RhwpEditorController`가 cursor 변경 시 selection을 collapsed 상태로 맞추고, 외부에서 selection을 지정하면 cursor가 selection 끝점으로 이동하도록 했다.
- `RhwpEditor` 위에 Flutter overlay를 추가해서 명령 대상 caret과 selection marker를 문서 영역에 그리도록 했다.
- widget test에 collapsed caret과 expanded selection 표시 검증을 추가했다.
- README와 CHANGELOG에 Flutter-native editor overlay의 현재 범위와 한계를 반영했다.

## 이 작업을 진행한 이유

- 초기 전환 계획에서 `RhwpEditor`는 Flutter overlay로 caret/selection을 그리고 실제 편집은 rhwp command API로 반영하는 구조를 목표로 했다.
- 기존 구현은 insert/delete command overlay만 있어서, 사용자가 현재 명령이 어느 section/paragraph/offset을 대상으로 하는지 문서 영역에서 확인하기 어려웠다.
- Rust 쪽 page layer tree와 텍스트 layout 좌표를 아직 Dart selection model에 연결하지 않았으므로, 먼저 controller 상태와 Flutter overlay rendering 경로를 분리해 두는 것이 다음 단계 작업에 유리하다.

## 이 작업을 통해 배울점

- Flutter editor UI는 문서 수정 command와 화면 selection state를 분리해야 한다. 그래야 selection 표시, command 적용, 저장/export를 각각 독립적으로 검증할 수 있다.
- HWP 문서의 정확한 caret 좌표는 paragraph offset만으로 계산할 수 없다. 글꼴, 줄바꿈, 표, page layer 정보가 필요하므로 이번 overlay는 command-target marker로 제한했다.
- controller에 selection model을 먼저 추가해 두면, 이후 rhwp의 page layer tree나 text layout API를 연결할 때 UI 계약을 크게 바꾸지 않고 좌표 계산만 교체할 수 있다.

## 검증

- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
- `git diff --check`
