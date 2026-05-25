# 2026-05-26 native editor desktop typing hold window

## 작업한 내용

- Flutter-native editor에서 데스크톱 텍스트 입력 commit 직후 일정 시간 동안 refresh 해제를 보류하는 hold window를 추가했다.
- macOS, Windows, Linux에서 스페이스나 텍스트 입력 직후 늦게 들어오는 `TextInputAction.done`, text input connection 종료, 짧은 focus 흔들림이 page SVG refresh를 바로 시작하지 않도록 했다.
- transient focus loss 테스트를 더 긴 데스크톱 입력 흔들림 시나리오로 갱신했다.
- CHANGELOG에 데스크톱 typing refresh hold 정책을 반영했다.

## 이 작업을 진행한 이유

예제 앱에서 스페이스나 텍스트를 입력할 때마다 화면이 refresh되는 것처럼 보이는 문제가 남아 있었다. 기존 로직은 즉시 들어오는 입력 action과 짧은 focus 흔들림은 막았지만, 실제 macOS 데스크톱 앱에서는 HWP 문서 command가 끝난 뒤 조금 늦게 입력 이벤트가 도착하거나 focus가 더 오래 흔들릴 수 있다.

문서 편집 중인 상태에서는 이 이벤트들을 입력 종료 신호로 보면 안 된다. 입력 commit 직후에는 Flutter overlay가 새 글자를 보여주고, Rust page SVG 동기화는 입력 상태가 안정된 뒤에만 진행하는 쪽이 더 자연스럽다.

## 이 작업을 통해 배울 점

- Flutter 데스크톱의 TextInput 이벤트는 순서와 timing이 모바일 키보드보다 불안정할 수 있다.
- 대형 HWP 문서에서는 Rust command, snapshot, render sync 비용이 커서 작은 입력 이벤트 하나가 바로 refresh로 이어지면 편집감이 크게 나빠진다.
- 입력 UX를 안정화하려면 command 적용, overlay 표시, SVG refresh 해제를 서로 다른 단계로 분리해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor holds text refresh across desktop input connection churn"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor ignores delayed desktop text input action while focused"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor holds text refresh across transient desktop focus loss"`
