# Native Editor Enter Split Paragraph

## 작업한 내용

- `RhwpCommand.splitParagraph`와 `RhwpDocument.splitParagraph()`를 Dart API에 추가했다.
- Rust facade의 command dispatcher가 `splitParagraph` JSON command를 받아 vendored rhwp의 `split_paragraph_native`로 전달하도록 했다.
- `RhwpNativeEditor`에서 Enter는 문단 분리, Shift+Enter는 같은 문단 안 줄바꿈 삽입으로 처리하도록 했다.
- Enter 후 cursor를 새 paragraph의 offset 0으로 이동시키고, Shift+Enter 후에는 같은 paragraph의 다음 offset으로 이동시키도록 했다.
- Dart command unit test, Flutter widget test, Rust facade test를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView 없이 실제 문서 편집기로 동작하려면 텍스트 삽입과 삭제만으로는 부족하다.
문서 편집에서 Enter는 새 문단을 만드는 핵심 입력이고, Shift+Enter는 문단을 나누지 않는 줄바꿈으로 구분되어야 한다.
upstream rhwp 코어에는 이미 문단 분리 API가 있으므로, 이를 Flutter bridge command surface로 올리는 것이 가장 안전한 구현 경로다.

## 이 작업을 통해 배울점

- Flutter-native editor는 UI 입력을 직접 처리하더라도 문서 변경의 source of truth는 Rust command API에 두는 편이 일관적이다.
- Enter와 Shift+Enter는 비슷해 보여도 HWP 문서 모델에서는 paragraph split과 inline line break라는 다른 command로 취급해야 한다.
- Rust facade, Dart command envelope, widget key handling을 같은 테스트 단위로 묶으면 입력 UX와 저장/export 가능한 문서 변경 경로가 함께 검증된다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "split paragraph command serializes"`
- `flutter test --plain-name "RhwpNativeEditor handles enter and soft line break"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
