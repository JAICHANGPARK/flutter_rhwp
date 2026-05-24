# 2026-05-24 Flutter Widget Verification

## 작업한 내용

- `test/rhwp_widget_test.dart`를 추가했다.
- `RhwpViewer`에 `RhwpSvgBuilder` 주입 지점을 추가해 기본 SVG 렌더러는 유지하면서 테스트와 커스텀 렌더링을 분리할 수 있게 했다.
- fake `RhwpSession`으로 Rust 브리지를 실제로 로드하지 않고 `RhwpViewer`와 `RhwpEditor` 위젯을 검증할 수 있게 했다.
- `RhwpViewer`가 SVG 페이지를 Flutter paint tree까지 전달하는지 테스트용 SVG painter와 `paints` matcher로 확인한다.
- zoom controller 변경이 레이아웃 폭을 바꾸면서 이미 렌더된 페이지를 불필요하게 다시 요청하지 않는지 확인한다.
- `RhwpEditor` command overlay에서 insert/delete 버튼이 `RhwpDocument` command envelope로 이어지고 cursor offset과 `onChanged`가 갱신되는지 확인한다.

## 이 작업을 진행한 이유

- 목표에 Flutter viewer/editor의 렌더링 검증이 포함되어 있다.
- committed golden PNG는 OS와 renderer 차이 때문에 CI에서 흔들릴 수 있고, `RenderRepaintBoundary.toImage()`는 현재 로컬 `flutter_tester` 정리 단계에서 멈추는 문제가 있어 paint command 검증으로 안정성을 우선했다.
- Rust facade 테스트만으로는 Flutter 위젯이 SVG를 실제로 렌더링하는지, zoom/change notifier가 레이아웃에 반영되는지, editor overlay가 command API로 연결되는지 알 수 없다.

## 이 작업을 통해 배울점

- 복잡한 FFI 의존 위젯도 세션 인터페이스를 fake로 대체하면 빠르고 안정적인 widget test를 작성할 수 있다.
- 렌더링 검증은 파일 기반 golden만 고집할 필요가 없고, paint command를 고정하면 플랫폼별 픽셀 차이와 테스트 러너의 이미지 캡처 문제를 줄일 수 있다.
- `RhwpSvgBuilder`처럼 작은 주입 지점을 두면 운영 기본 렌더러는 유지하면서 테스트에서는 결정적인 painter를 사용할 수 있다.
- editor가 아직 완전한 caret/selection 모델을 갖추지 않았더라도, 현재 제공하는 command overlay의 계약은 테스트로 고정해야 후속 편집 UI 확장 때 회귀를 줄일 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart`
- `flutter test`
- `flutter analyze`
