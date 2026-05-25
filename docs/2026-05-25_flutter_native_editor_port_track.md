# Flutter Native Editor Port Track

## 작업한 내용

- `RhwpNativeEditor` public widget을 추가해 WebView가 아닌 100% Flutter 위젯 기반 editor track을 열었다.
- 기존 `RhwpEditor` 화면을 하단 command strip에서 Flutter toolbar + menu tabs + page viewport + status bar 구조로 바꿨다.
- 기존 `RhwpCommandEditor`는 compatibility wrapper로 유지했다.
- example의 `Commands` 토글을 `Native editor`로 바꾸고, native mode에서 `RhwpNativeEditor`를 사용하도록 연결했다.
- widget test가 Flutter-native toolbar tab과 insert/delete command flow를 검증하도록 갱신했다.

## 이 작업을 진행한 이유

upstream `rhwp/web` editor는 `editor.js`가 `HwpDocument` WASM API를 직접 호출하고,
`text_selection.js`, `format_toolbar.js`, `char_shape_dialog.js`, CSS/DOM/Canvas 이벤트로
입력, 선택, 툴바를 구성한다. Flutter 플러그인에서는 이 DOM/Canvas 레이어를 WebView로
계속 감쌀 수는 있지만, 목표는 같은 기능을 Flutter 위젯으로 단계적으로 포팅하는 것이다.

이번 작업은 WebView 기반 `RhwpFullEditor`를 유지하면서, 별도의 Flutter-native editor
surface를 실제 API와 example에 노출하는 첫 단계다.

## 이 작업을 통해 배울점

- Web editor를 Flutter로 옮기는 일은 파일 변환이 아니라 UI/입력/selection/toolbar layer를
  다시 설계하는 작업이다.
- Flutter-native editor는 `RhwpDocument`와 Rust command API를 source of truth로 두고,
  Flutter 위젯은 toolbar, page viewport, caret/selection overlay, status를 담당하는 구조가 맞다.
- IME, clipboard, table selection, object hit-test, 서식 명령은 다음 단계에서 각각 작은
  기능 단위로 포팅해야 한다.

## 검증

- `dart format lib test example/lib example/test example/integration_test`
- `flutter analyze`
- `flutter test`
- `(cd example && flutter test)`
- `git diff --check`
