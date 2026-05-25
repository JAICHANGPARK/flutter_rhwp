# 2026-05-26 native editor desktop text input action hold

## 작업한 내용

- Flutter-native editor에서 macOS, Linux, Windows의 delayed `TextInputAction.done` 이벤트가 입력 중 deferred page refresh를 풀지 않도록 막았다.
- 데스크톱에서는 에디터 포커스가 유지되는 동안 text input action을 입력 세션 종료 신호로 보지 않고, 포커스가 빠질 때 refresh를 해제하도록 했다.
- 데스크톱 text input connection churn 테스트를 갱신하고, action ignore window 이후 들어오는 delayed action도 refresh를 유발하지 않는 위젯 테스트를 추가했다.
- README와 CHANGELOG에 데스크톱 입력 refresh 정책을 반영했다.

## 이 작업을 진행한 이유

예제 앱에서 스페이스나 텍스트 입력 후 페이지가 매번 refresh되는 문제가 남아 있었다. 이전 수정은 즉시 들어오는 `TextInputAction.done`과 connection churn은 막았지만, 큰 HWP 문서에서는 Rust edit command가 끝난 뒤 늦게 들어오는 desktop text input action이 deferred refresh를 다시 열 수 있었다.

데스크톱에서 이 action은 사용자가 편집을 끝냈다는 명시적인 신호가 아니므로, 에디터 포커스가 유지되는 동안에는 refresh 해제 조건으로 쓰면 안 된다.

## 이 작업을 통해 배울 점

- Flutter 데스크톱 입력 이벤트에서 `TextInputAction.done`은 모바일 키보드의 완료 버튼과 같은 의미로 취급하기 어렵다.
- 대형 문서 편집에서는 명령 실행 시간이 action ignore window보다 길어질 수 있으므로, 시간 기반 ignore만으로는 per-character refresh를 안정적으로 막기 어렵다.
- Rust 문서 상태는 즉시 갱신하되, 렌더 SVG 동기화는 포커스/입력 세션 기준으로 분리해야 에디터 입력 UX가 안정된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor ignores delayed desktop text input action while focused"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor holds text refresh across desktop input connection churn"`
