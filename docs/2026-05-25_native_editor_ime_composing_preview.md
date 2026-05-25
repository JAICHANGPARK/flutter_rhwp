# Native Editor IME Composing Preview

## 작업한 내용

- `RhwpNativeEditor`가 IME composing range를 가진 `TextEditingValue`를 받으면 overlay를 다시 그리도록 했다.
- composing 중인 문자열을 caret 위치 근처에 표시하는 `_ComposingPreview` 위젯을 추가했다.
- page layer tree 기반 caret 위치와 fallback caret 위치 양쪽에서 composing preview가 보이도록 연결했다.
- composing이 끝나고 최종 문자열이 Rust `insertText` command로 commit되면 preview가 사라지도록 했다.
- widget test에서 한글 조합 중간 상태인 `ㅎ`은 command 없이 preview로만 보이고, 최종 `한`만 insert되는 흐름을 검증했다.

## 이 작업을 진행한 이유

이전 단계에서 IME 입력은 받을 수 있었지만 composing 중간 상태가 화면에 보이지 않았다.
한글 입력은 조합 중인 글자를 사용자가 눈으로 확인하면서 입력해야 하므로, WebView 없는 Flutter-native editor에서도
문서 caret 근처에 composing preview를 표시해야 실제 편집기처럼 동작한다.

## 이 작업을 통해 배울점

- IME composing 상태는 문서 모델에 바로 쓰면 안 되고, UI overlay에서 임시 상태로 보여줘야 한다.
- composing preview는 caret/selection overlay와 같은 좌표계를 써야 사용자가 보고 있는 문서 위치와 입력 위치가 어긋나지 않는다.
- Flutter input buffer와 Rust document command를 분리하면 조합 중간 상태와 최종 commit을 명확하게 다룰 수 있다.
- 다음 단계에서는 preview 위치를 실제 glyph advance에 맞춰 더 정교하게 보정하고, multi-character composition과 paragraph boundary를 다듬어야 한다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test --plain-name "RhwpNativeEditor commits text input after IME composition"`
- `flutter test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
