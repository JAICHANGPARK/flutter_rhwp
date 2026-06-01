# Flutter-native editor delete paragraph

## 작업한 내용

- rhwp core의 `delete_paragraph_native`를 `deleteParagraph` command envelope로 노출했다.
- Dart `RhwpCommand.deleteParagraph()`와 `RhwpDocument.deleteParagraph()`를 추가했다.
- `RhwpNativeEditor` 편집 리본에 현재 본문 문단을 삭제하는 버튼을 추가했다.
- 삭제 후 커서는 core가 반환하는 남은 문단 수를 기준으로 같은 index 또는 마지막 문단으로 보정하도록 했다.
- Rust command smoke test, Dart command serialization/convenience test, widget toolbar test를 갱신했다.

## 이 작업을 진행한 이유

직전 작업에서 빈 문단 삽입을 Flutter-native editor에 연결했기 때문에, 문단 구조 편집의 반대 방향인 문단 삭제도 같은 surface에서 제공해야 한다. upstream rhwp core와 WASM API에는 이미 `deleteParagraph`가 있으므로 JS/WebView editor를 호출하지 않고 FRB command 경로로 직접 연결했다.

## 이 작업을 통해 배울점

- 문단 삭제는 텍스트 삭제와 달리 문서 구조 자체를 바꾸므로, 삭제 후 cursor paragraph를 남은 문단 범위 안으로 보정해야 한다.
- Flutter-native editor 리본 버튼은 단순 UI 추가가 아니라 Dart command, Rust dispatch, core mutation, cursor state, refresh가 함께 맞아야 실제 편집 기능이 된다.
- WebView fallback을 유지하더라도 upstream core API를 Flutter surface에 하나씩 옮기면 native editor가 점진적으로 full editor 역할에 가까워진다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor edit ribbon deletes the current paragraph"`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter analyze`
- `git diff --check`
