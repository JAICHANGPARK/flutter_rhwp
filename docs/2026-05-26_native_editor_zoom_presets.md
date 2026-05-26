# 2026-05-26 native editor zoom presets

## 작업한 내용

- `RhwpViewerController`의 줌 단계를 upstream web editor와 같은 `25%, 50%, 75%, 100%, 125%, 150%, 200%, 300%` preset으로 맞췄다.
- Flutter-native editor의 view ribbon/status bar 줌 버튼 비활성 기준을 25%/300%로 맞췄다.
- 임의 zoom 값에서 zoom in/out을 눌렀을 때 가장 가까운 다음 preset으로 이동하는 회귀 테스트를 추가했다.
- README와 CHANGELOG에 upstream-style zoom preset 동작을 반영했다.

## 이 작업을 진행한 이유

upstream web editor는 고정 zoom preset을 사용한다. Flutter-native editor가 25%씩 계속 증가하고 600%까지 올라가면 WebView fallback과 Flutter-native surface 사이에서 같은 문서를 다룰 때 배율 감각이 달라진다.

줌은 보기 기능이지만 편집 UX에도 직접 영향을 준다. caret hit-test, selection overlay, 표/객체 선택이 모두 같은 viewport 모델 위에서 동작하기 때문에 web editor와 같은 preset 체계를 쓰는 편이 parity를 맞추는 데 유리하다.

## 이 작업을 통해 배울 점

- controller는 사용자가 임의 zoom 값을 직접 넣을 수 있도록 두되, 버튼/단축키 기반 zoom 이동은 제품 preset을 따라가는 방식이 가장 덜 깨진다.
- Flutter-native editor의 toolbar와 status bar는 같은 controller 상수를 참조해야 최대/최소 zoom 비활성 조건이 어긋나지 않는다.
- WebView fallback과 native editor를 함께 제공할 때는 문서 편집 명령뿐 아니라 보기 모델도 맞춰야 전환 UX가 자연스럽다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer uses upstream-style zoom presets"`은 sandbox의 `127.0.0.1:0` socket 생성 제한 때문에 실행 환경에서 막힌다.
