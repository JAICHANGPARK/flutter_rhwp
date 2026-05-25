# Native Editor Character Formatting

## 작업한 내용

- `RhwpCommand.applyCharFormat`와 `RhwpDocument.applyCharFormat()`를 Dart API에 추가했다.
- Rust facade가 `applyCharFormat` JSON command를 받아 rhwp core의 `apply_char_format_native`로 전달하도록 했다.
- `RhwpNativeEditor` toolbar의 Bold, Italic, Underline 버튼을 실제 command dispatch에 연결했다.
- Cmd/Ctrl+B, Cmd/Ctrl+I, Cmd/Ctrl+U 단축키를 같은 command 흐름에 연결했다.
- 현재 단계에서는 같은 section/paragraph 안의 선택 영역에 대해 bold, italic, underline 적용을 지원한다.
- Dart command unit test, Flutter widget test, Rust facade test를 추가했다.

## 이 작업을 진행한 이유

WebView 없이 Flutter-native editor를 만들려면 입력과 selection 다음으로 toolbar 서식 명령이 필요하다.
upstream web editor도 Rust/WASM document API에 서식 적용을 위임하므로, Flutter에서도 문서 모델을 직접 만지지 않고 Rust bridge command로 전달하는 구조가 맞다.
이번 작업은 웹 에디터 toolbar의 가장 기본 기능인 굵게, 기울임, 밑줄을 Flutter widget toolbar와 키보드 shortcut에서 사용할 수 있게 만든 첫 단계다.

## 이 작업을 통해 배울점

- Flutter toolbar는 UI 상태를 직접 문서에 반영하지 않고, Rust command envelope만 생성하는 역할로 두면 저장/export 경로와 일관된다.
- collapsed cursor에서 다음 입력 서식을 유지하는 기능과 selected range에 서식을 적용하는 기능은 별도 상태 모델이 필요하므로 분리해서 구현하는 편이 안전하다.
- multi-paragraph formatting은 paragraph별 end offset 계산이 필요하므로 이번 단계에서는 same-paragraph selection으로 범위를 제한하고 다음 작업으로 확장한다.
- toolbar 버튼과 keyboard shortcut이 같은 helper를 타도록 만들면 UI와 단축키 동작 차이를 줄일 수 있다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "apply char format command serializes"`
- `flutter test --plain-name "RhwpNativeEditor applies character formatting"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
