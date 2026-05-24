# 2026-05-25 Viewer Virtualization Test

## 작업한 내용

- `test/rhwp_widget_test.dart`에 `RhwpViewer` page virtualization 회귀 테스트를 추가했다.
- fake `RhwpSession`이 25쪽 문서를 제공하도록 만들고, 첫 viewport에서는 일부 페이지만 SVG 렌더링 요청이 발생하는지 확인했다.
- 테스트에서 vertical scroll을 수행한 뒤 새 페이지 렌더링 요청이 추가되지만 전체 문서를 한 번에 렌더링하지 않는지 검증했다.
- CHANGELOG에 `RhwpViewer` lazy SVG page rendering 테스트 추가 내용을 반영했다.

## 이 작업을 진행한 이유

- 초기 테스트 계획에는 `RhwpViewer`의 lazy page loading과 page virtualization 검증이 포함되어 있었다.
- 기존 위젯 테스트는 SVG paint, zoom cache, editor command 연결은 확인했지만, 긴 문서에서 전체 페이지를 한 번에 렌더링하지 않는다는 보장은 없었다.
- HWP 문서는 수십~수백 페이지가 될 수 있으므로 viewer가 현재 viewport 주변의 페이지만 요청하는지 회귀 테스트로 잡아야 한다.

## 이 작업을 통해 배울점

- Flutter `ListView`는 viewport뿐 아니라 기본 cache extent 범위의 일부 item도 미리 build할 수 있다. 테스트는 "정확히 한 페이지만"이 아니라 "전체를 한 번에 렌더링하지 않는다"는 성질을 검증해야 안정적이다.
- FRB/Rust를 로드하지 않는 fake session 테스트로도 viewer의 렌더링 요청 패턴을 충분히 검증할 수 있다.
- 스크롤 동작을 테스트할 때는 중첩된 scrollable 중 실제 vertical `Scrollable`을 지정해야 의도가 명확해진다.

## 검증

- `flutter test test/rhwp_widget_test.dart`
