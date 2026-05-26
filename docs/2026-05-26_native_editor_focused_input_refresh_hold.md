# 2026-05-26 native editor focused input refresh hold

## 작업한 내용

- Flutter-native editor가 포커스를 가진 상태에서는 `TextInputAction.done`이 들어와도 deferred page refresh를 풀지 않도록 수정했다.
- 텍스트 입력 테스트 helper는 명시적으로 focus를 해제해야 refresh가 진행되도록 갱신했다.
- focus가 유지된 상태에서 Space 입력 후 action이 들어와도 page SVG render가 다시 호출되지 않는 회귀 테스트를 추가했다.
- README와 CHANGELOG에 focused text input refresh hold 정책을 반영했다.

## 이 작업을 진행한 이유

예제 앱에서 Space나 텍스트를 입력할 때마다 화면이 refresh되는 것처럼 보이는 경로가 남아 있었다. 원인은 입력 action이나 connection-close 이벤트가 문서 포커스가 유지된 상태에서도 deferred refresh를 해제할 수 있다는 점이다.

문서 편집 중에는 Rust 문서에는 명령을 즉시 반영하되, 화면의 무거운 SVG 재렌더는 사용자가 입력 세션을 벗어날 때까지 미루는 편이 자연스럽다. 그 사이에는 Flutter overlay가 새 텍스트와 caret을 보여준다.

## 이 작업을 통해 배울 점

- `TextInputAction.done`은 항상 사용자가 편집을 끝냈다는 뜻이 아니다. 특히 데스크톱과 웹 입력에서는 Space나 IME 처리 중에도 들어올 수 있다.
- 편집기 UX에서는 command 적용, optimistic overlay, page SVG refresh를 분리해야 입력감이 안정된다.
- 테스트에서는 action 이벤트와 focus release를 분리해서 검증해야 실제 앱에서 보이는 refresh 경로를 더 정확히 잡을 수 있다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor keeps focused text refresh held after input action"`은 sandbox의 `127.0.0.1:0` socket 생성 제한 때문에 실행 환경에서 막힌다.
