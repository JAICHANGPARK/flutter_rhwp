# Native editor controller dirty state

## 작업한 내용

- `RhwpEditorController`에 `dirty` getter/setter를 추가했다.
- host app이 저장/폐기 완료 후 상태를 정리할 수 있도록 `RhwpEditorController.markClean()`을 추가했다.
- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`의 edit/save/document replacement dirty 흐름을 controller 상태와 동기화했다.
- `onDirtyChanged` callback뿐 아니라 `controller.dirty`로도 현재 수정 여부를 조회할 수 있게 했다.
- unit/widget test로 controller dirty notification, 편집/저장 dirty 상태, document replacement clean 상태를 검증했다.

## 이 작업을 진행한 이유

Flutter-native editor가 실제 앱의 문서 편집 surface가 되려면 host app이 New/Open/Close 전에 현재 문서가 수정되었는지 즉시 조회할 수 있어야 한다. callback은 상태 변화 알림에 좋지만, 저장/폐기 다이얼로그나 route guard에서는 현재 상태를 controller에서 직접 읽는 API가 더 안정적이다.

기존 `onDirtyChanged`를 유지하면서 controller에도 같은 상태를 싣는 방식으로, Flutter 앱이 dirty indicator, close guard, external save/discard flow를 더 쉽게 구현할 수 있게 했다.

## 이 작업을 통해 배울점

- editor의 dirty 상태는 UI callback과 controller state가 함께 있어야 앱 통합성이 좋아진다.
- document replacement는 build/update 중 발생할 수 있으므로 callback과 controller notification을 다음 프레임으로 미루어 Flutter build lifecycle과 충돌하지 않게 처리해야 한다.
- host app이 editor 밖에서 저장이나 폐기를 완료하는 경우를 위해 `markClean()` 같은 명시적 escape hatch가 필요하다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpEditorController exposes dirty state notifications"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reports dirty state for edits and saves"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reports clean state when document is replaced"
```
