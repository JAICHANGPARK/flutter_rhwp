# Flutter-native editor insert paragraph

## 작업한 내용

- rhwp core의 `insert_paragraph_native`를 `insertParagraph` command envelope로 노출했다.
- Dart `RhwpCommand.insertParagraph()`와 `RhwpDocument.insertParagraph()`를 추가했다.
- `RhwpNativeEditor` 입력 리본에 현재 커서 뒤로 빈 문단을 삽입하는 버튼을 추가했다.
- Rust command smoke test, Dart command serialization/convenience test, widget toolbar test를 갱신했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView 기반 full editor를 대체하려면 Enter로 현재 문단을 나누는 동작뿐 아니라, 문서 구조에 빈 문단을 직접 추가하는 편집 명령도 필요하다. upstream rhwp core에는 이미 빈 문단 삽입 API가 있으므로 JS editor를 거치지 않고 FRB command surface와 Flutter 리본 UI에 연결했다.

## 이 작업을 통해 배울점

- native editor 기능은 Flutter 버튼, Dart command envelope, Rust dispatch, rhwp core API가 한 줄로 이어져야 실제 편집 기능이 된다.
- 문단 삽입은 offset이 아니라 section/paragraph index 기반 명령이므로, Flutter UI에서는 현재 커서의 다음 paragraph index를 명확히 계산해야 한다.
- WebView fallback을 유지하더라도 upstream core API를 하나씩 Flutter-native surface에 붙이면 장기적으로 플랫폼별 WebView 의존도를 줄일 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor insert ribbon adds a blank paragraph"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts page and column breaks"`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter analyze`
- `git diff --check`
