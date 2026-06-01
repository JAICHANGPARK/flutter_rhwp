# Native editor table cell resize

## 작업한 내용

- `RhwpTableCellResize` 모델과 `RhwpCommand.resizeTableCells`를 추가했다.
- Dart `RhwpDocument.resizeTableCells` 공개 API를 추가했다.
- Rust `apply_command` 브리지에서 rhwp core의 `resizeTableCells` API를 호출하도록 연결했다.
- Flutter-native 셀 속성 다이얼로그에서 여러 셀이 선택된 상태로 width/height를 바꾸면 선택된 셀들의 크기 델타를 `resizeTableCells`로 한 번에 적용하도록 했다.
- 단일 셀 선택에서는 기존 `setCellProperties` 흐름을 유지한다.
- Dart command serialization, document convenience API, native editor widget interaction, Rust command bridge 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream web editor는 표 셀 선택 상태에서 셀 단위 편집을 문서 코어 명령으로 처리한다. Flutter-native 에디터도 표를 실제 WYSIWYG 편집 대상으로 만들려면 셀 하나만 수정하는 경로를 넘어, 선택된 셀 범위에 크기 변경을 적용할 수 있어야 한다.

`setCellProperties`는 단일 셀 속성 변경에 적합하고, `resizeTableCells`는 여러 셀의 width/height 델타를 배치로 적용하는 코어 API다. 여러 셀 선택 상태에서는 이 API를 쓰는 것이 upstream 구조와 더 잘 맞는다.

## 이 작업을 통해 배울 점

- Flutter-native editor 포팅은 UI 위젯을 추가하는 것보다, Flutter 선택 상태를 rhwp core의 정확한 명령 단위에 연결하는 작업이 핵심이다.
- 표 셀 크기 변경은 절대값보다 델타 기반 API가 여러 셀 선택에 적합하다.
- 단일 셀 편집과 범위 편집을 같은 다이얼로그에서 처리하되, 내부 명령은 상황에 맞게 분기하는 방식이 사용자 경험과 코어 모델을 모두 지키기 쉽다.
