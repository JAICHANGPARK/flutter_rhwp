# Full editor dirty bridge

## 작업한 내용

- `RhwpFullEditorController`와 `RhwpWebEditorController`에 `dirty`, `markClean()`, listener 알림을 추가했다.
- `RhwpFullEditor`와 `RhwpWebEditor`에 `onDirtyChanged` 콜백을 추가했다.
- Web full editor는 browser window custom event로 dirty 상태를 Dart controller에 전달하도록 했다.
- Desktop full editor host는 WebView JavaScript channel 메시지로 dirty 상태를 Dart controller에 전달하도록 했다.
- upstream editor 내부에 입력, 붙여넣기, 삭제, Enter/Tab, drag/drop, toolbar-like click listener를 삽입해 보수적으로 dirty 상태를 감지한다.
- example 앱의 New/Open/Close guard, 저장 완료, 폐기, native/full editor 전환 흐름이 full editor dirty 상태까지 보도록 연결했다.
- controller dirty state widget test를 추가했다.

## 이 작업을 진행한 이유

full editor는 upstream `@rhwp/editor` UI가 내부에서 편집을 처리한다. 기존에는 Flutter 쪽에서 full editor 내부 편집 여부를 알기 어려워서, full editor에서 문서를 수정한 뒤 New/Open/Close를 누르거나 native editor로 돌아갈 때 dirty 상태가 정확하지 않았다.

이 작업은 WebView/upstream editor fallback을 유지하면서도 Flutter host 앱의 파일 수명주기와 저장 guard가 같은 기준으로 동작하도록 하기 위한 것이다. Flutter-native editor를 계속 키우더라도, full editor fallback은 실제 사용자에게 필요한 기능이므로 dirty 상태를 public controller API로 노출해야 한다.

## 이 작업을 통해 배울점

- WebView에 올라간 editor도 Flutter 앱의 file lifecycle 계약에 참여해야 한다.
- upstream editor가 공식 dirty 이벤트를 제공하지 않으면 host가 감지하는 conservative bridge가 필요하다.
- dirty bridge는 저장 기능이 아니다. 저장 완료나 변경 폐기는 host app이 처리한 뒤 `markClean()`으로 명시해야 한다.
- editor mode switch는 외부 저장이 아니라 in-memory handoff라서 dirty 상태를 유지해야 한다.

## 남은 점

- 현재 bridge는 공식 upstream edit event가 아니라 DOM/input/key/click 기반 conservative 감지다.
- 실제 macOS/Windows/Linux WebView와 Web Chrome에서 toolbar command별 dirty 감지를 수동 검증해야 한다.
- upstream `@rhwp/editor`가 공식 dirty/edit event를 제공하면 그 event로 교체하는 것이 더 정확하다.

## 검증

```sh
dart format lib/src/rhwp_web_editor_stub.dart lib/src/rhwp_web_editor_web.dart lib/src/rhwp_full_editor_stub.dart lib/src/rhwp_full_editor_web.dart lib/src/rhwp_full_editor_io.dart example/lib/main.dart test/rhwp_widget_test.dart
flutter test test/rhwp_widget_test.dart --plain-name "RhwpFullEditorController exposes dirty state notifications"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpWebEditorController exposes dirty state notifications"
```
