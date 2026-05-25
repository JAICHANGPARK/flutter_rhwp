# 2026-05-26 native editor page column break

## 작업한 내용

- `RhwpCommand.insertPageBreak`와 `RhwpCommand.insertColumnBreak`를 Dart 공개 command surface와 `RhwpDocument` 편의 메서드에 추가했다.
- Rust facade의 `apply_command`에서 `insert_page_break_native`, `insert_column_break_native`로 라우팅하도록 연결했다.
- Flutter-native editor 입력 리본에 쪽 나누기와 단 나누기 버튼을 추가했다.
- Ctrl/Cmd+Enter는 쪽 나누기, Ctrl/Cmd+Shift+Enter는 단 나누기로 처리하도록 키보드 입력 경로를 연결했다.
- Dart command serialization, widget editor 버튼/단축키, Rust facade round-trip 테스트를 추가했다.

## 이 작업을 진행한 이유

HWP 에디터에서 쪽 나누기와 단 나누기는 문서 구조 편집의 기본 기능이다. upstream rhwp core에는 이미 해당 native command가 있으므로, Flutter-native editor가 WebView fallback에 의존하지 않고 같은 문서 구조 편집을 수행할 수 있게 노출하는 것이 맞다.

## 이 작업을 통해 배울 점

- Flutter-native editor는 UI 버튼과 키보드 shortcut을 같은 내부 command 함수로 모아야 동작 차이가 줄어든다.
- Rust core에 이미 있는 기능은 JS/Web editor를 우회하지 말고 FRB facade command로 직접 노출하는 편이 유지보수에 유리하다.
- 문단을 분리하는 명령은 결과 JSON의 `paraIdx`와 `charOffset`을 읽어 cursor를 core 결과에 맞춰 동기화해야 한다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts page and column breaks"`
- `cargo test -p flutter_rhwp --lib`
- `flutter analyze`
- `git diff --check`
