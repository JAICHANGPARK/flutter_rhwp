# 2026-05-25 Web Example Default Editor Mode

## 작업한 내용

- Web에서 example app의 기본 editor mode를 upstream `@rhwp/editor`로 변경했다.
- Web editor mode에서는 샘플 asset이나 file picker로 읽은 bytes를 곧바로 `RhwpWebEditor`에 전달하고, 시작 시 `Rhwp.open`을 호출하지 않도록 했다.
- Export 버튼이 Flutter bridge 문서뿐 아니라 Web editor instance에서도 동작하도록 document null 상태를 허용했다.
- 사용자가 `Flutter` mode로 전환할 때 source bytes가 있으면 그 시점에 FRB bridge로 문서를 열도록 했다.
- Flutter-native editor에서 변경이 발생하면 최신 HWP snapshot을 `_sourceBytes`에 갱신해서 Web editor로 전환할 때 가능한 한 최신 bytes를 넘기도록 했다.
- example widget test를 Web platform에서도 실행할 수 있게 하고, Web에서는 mode toggle이 표시되는지 확인하도록 했다.
- README와 CHANGELOG에 Web example의 기본 동작 변경을 반영했다.

## 이 작업을 진행한 이유

- Web에서 앱 시작과 동시에 Flutter bridge가 `Rhwp.open`을 호출하면 FRB WASM 초기화가 먼저 필요하다.
- 브라우저가 COOP/COEP 헤더를 받기 전이거나 WASM bundle 경로가 맞지 않으면 `WebAssembly.instantiate()` 단계에서 실패할 수 있다.
- 사용자는 upstream `@rhwp/editor`가 Web에서 바로 제공하는 에디터 UI도 함께 쓰고 싶다고 요청했다. 따라서 Web example의 기본 경로는 upstream Web editor를 먼저 보여주고, Flutter bridge는 명시적으로 선택했을 때 초기화하는 쪽이 더 안전하다.

## 이 작업을 통해 배울점

- Flutter Web에서 native/WASM bridge와 JS 기반 editor embed를 모두 제공할 때는 시작 경로를 분리해야 한다.
- Web editor mode는 bytes를 직접 전달받는 구조가 적합하고, Flutter bridge mode는 동일 bytes를 나중에 `Rhwp.open`으로 여는 lazy 초기화가 적합하다.
- WebAssembly cross-origin isolation 문제는 기능 전체를 막는 에러가 되기 쉽다. 대체 UI가 있는 경우 eager initialization을 피하면 사용자가 최소한 Web editor 기능을 계속 사용할 수 있다.

## 검증

- `dart format example/lib/main.dart example/test/widget_test.dart`
- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
- `cd example && flutter test --platform chrome test/widget_test.dart`
- `git diff --check`
