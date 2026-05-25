# 2026-05-25 native editor undo redo

## 작업한 내용

- Dart `RhwpCommand`에 `saveSnapshot`, `restoreSnapshot`, `discardSnapshot` command envelope을 추가했다.
- `RhwpDocument.saveSnapshot()`, `restoreSnapshot()`, `discardSnapshot()` 편의 API를 추가했다.
- Rust `apply_command` dispatch에서 rhwp core의 `save_snapshot_native()`, `restore_snapshot_native()`, `discard_snapshot_native()`를 호출하도록 연결했다.
- `RhwpNativeEditor`의 `_runEdit()`이 편집 전 snapshot을 저장하고, 새 편집 시 redo stack을 정리하도록 했다.
- Flutter-native 에디터 `편집` 리본에 Undo/Redo 버튼을 추가하고 `Ctrl/Cmd+Z`, `Ctrl/Cmd+Y`, `Ctrl/Cmd+Shift+Z` 단축키를 연결했다.
- Dart serialization test, Flutter widget test, Rust command integration test를 추가/확장했다.

## 이 작업을 진행한 이유

- upstream 웹 에디터 수준의 기본 편집 UX로 가려면 텍스트/서식/표 command뿐 아니라 실행 취소와 다시 실행이 필요하다.
- rhwp core에 이미 snapshot store가 있으므로 Flutter에서 임의로 문서 상태를 복제하지 않고 Rust document engine을 source of truth로 두는 것이 맞다.
- undo/redo를 `_runEdit()` 공통 경로에 넣으면 텍스트 입력, 서식, 표 편집, 머리말/꼬리말 생성 같은 기존 Flutter-native command가 같은 방식으로 되돌릴 수 있다.

## 이 작업을 통해 배울점

- undo/redo는 단일 command가 아니라 편집 전 상태 저장, restore, redo stack 정리, viewer rerender까지 포함하는 editor state 기능이다.
- Flutter-native editor는 UI state만 들고, 문서 상태 snapshot은 Rust core에 맡기는 편이 저장/export와의 일관성을 유지하기 쉽다.
- 새 편집이 발생하면 redo stack을 버려야 하므로 snapshot discard 경로도 공개 API와 테스트에 포함해야 한다.

## 검증

- Dart test로 snapshot command JSON과 `RhwpDocument.saveSnapshot()`의 `snapshotId` 파싱을 확인했다.
- Flutter widget test로 텍스트 삽입 후 Undo/Redo 버튼이 save/restore/discard snapshot command 흐름을 호출하는지 확인했다.
- Rust test에서 snapshot 저장, 임시 편집, restore, discard 후 기존 HWP/HWPX export/reopen 흐름이 유지되는지 확인했다.
