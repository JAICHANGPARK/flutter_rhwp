# 2026-06-02 native editor null focus refresh hold

## 작업한 내용

- `RhwpNativeEditor`의 데스크톱 text input refresh hold 조건을 조정했다.
- macOS/Linux/Windows에서 입력 중 primary focus가 잠깐 `null`이 되는 경우를 실제 외부 포커스 이동으로 보지 않도록 했다.
- deferred page refresh는 편집기 밖의 실제 focus target이 잡힐 때만 풀리도록 테스트를 갱신했다.
- desktop connection churn, delayed input action, ancestor focus, transient focus loss, slow commit 테스트를 새 기준에 맞게 보강했다.

## 이 작업을 진행한 이유

대형 HWP 문서에서 Space나 텍스트를 입력할 때마다 페이지가 다시 렌더되는 것처럼 보이는 문제가 남아 있었다. 이전 구현은 `holdTextRefreshWhileFocused`가 켜져 있어도 데스크톱 text input 과정에서 primary focus가 잠시 비는 상황을 입력 종료로 볼 수 있었다.

실제 사용자는 아직 문서 안에서 계속 입력 중이므로, `null` focus는 refresh release 신호로 쓰면 안 된다. Flutter-native 에디터는 Rust 문서 상태에는 즉시 command를 적용하고, 화면의 SVG 재렌더는 사용자가 편집기 밖으로 명확히 이동할 때까지 미루는 쪽이 안정적이다.

## 이 작업을 통해 배울점

- 데스크톱 Flutter text input은 글자 commit, action, connection close, focus 변경 순서가 플랫폼별로 흔들릴 수 있다.
- `primaryFocus == null`은 사용자가 편집을 끝냈다는 의미가 아니라 transient input churn일 수 있다.
- 대형 문서 편집기에서는 "데이터 반영"과 "무거운 페이지 렌더 동기화"를 분리해야 입력 UX가 안정된다.
- refresh release 조건은 외부 포커스처럼 명확한 사용자 의도만 기준으로 삼는 편이 안전하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor .*desktop|RhwpNativeEditor .*text refresh|RhwpNativeEditor .*text input"`
