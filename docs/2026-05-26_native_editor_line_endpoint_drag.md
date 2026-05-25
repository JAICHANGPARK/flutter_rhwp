# 2026-05-26 native editor line endpoint drag

## 작업한 내용

- Dart `RhwpCommand`와 `RhwpDocument`에 `moveLineEndpoint` API를 추가했다.
- Rust facade command enum이 vendored rhwp의 기존 `move_line_endpoint_native`로 라우팅하도록 연결했다.
- page layer tree object 모델이 line paint op의 `x1`, `y1`, `x2`, `y2` 끝점 정보를 읽을 수 있게 했다.
- Flutter-native editor에서 선택된 line object는 사각형 resize handle 대신 시작점/끝점 handle을 보여주고, 끝점 드래그를 Rust line endpoint command로 커밋하도록 했다.
- Dart API, Rust facade, Flutter widget 테스트를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor를 실제 HWP 편집기처럼 만들려면 텍스트와 표뿐 아니라 도형/객체 편집이 필요하다. 직선 객체는 일반 사각형 resize와 다르게 시작점과 끝점을 직접 움직이는 UX가 자연스럽다.

rhwp core에는 이미 line endpoint 이동 기능이 있었기 때문에, Flutter 쪽에서는 새 엔진을 만들기보다 기존 Rust core command를 안전하게 노출하고 page overlay에서 해당 조작을 연결하는 방식이 가장 맞다.

## 이 작업을 통해 배울 점

- Flutter-native editor의 객체 편집은 page layer tree의 화면 좌표와 Rust object property 좌표를 함께 매핑해야 한다.
- 도형 종류별로 같은 bounds resize UX를 쓰기보다, line처럼 고유한 편집 handle이 필요한 객체를 별도 처리해야 편집기 사용감이 좋아진다.
- vendored rhwp에 이미 있는 기능은 FRB command surface로 연결하면 WebView fallback 없이도 native editor 기능을 단계적으로 확장할 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor drags selected line endpoints"`
- `cargo test --manifest-path rust/Cargo.toml applies_move_line_endpoint_command`
