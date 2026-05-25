# 2026-05-26 native editor slow input refresh hold

## 작업한 내용

- Flutter-native editor가 텍스트 입력 command 실행 중인 상태도 page SVG refresh 보류 조건으로 보도록 변경했다.
- macOS 같은 데스크톱 환경에서 입력 command가 끝나기 전에 focus, text input action, connection close 이벤트가 먼저 들어와도 즉시 refresh가 풀리지 않게 했다.
- 입력 command가 끝난 뒤 에디터 포커스가 다시 들어오면 이미 예약된 deferred refresh 타이머를 취소하고 입력 보류 상태로 되돌리도록 했다.
- 느린 `saveSnapshot` 이후 focus가 돌아오는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

큰 HWP 문서에서는 `saveSnapshot`, `insertText`, SVG 렌더 비용이 커질 수 있다. 이때 데스크톱 text input 이벤트가 command 완료보다 먼저 흔들리면, 에디터는 사용자가 계속 입력 중인데도 입력이 끝난 것으로 판단해 페이지를 다시 렌더링할 수 있었다.

사용자 입장에서는 스페이스나 글자를 넣을 때마다 화면이 refresh되는 것처럼 보인다. 입력 commit은 Rust 문서에 즉시 반영하되, 화면 동기화는 입력 흐름이 안정된 뒤로 미루는 것이 native editor UX에 맞다.

## 이 작업을 통해 배울 점

- 데스크톱 Flutter text input 이벤트 순서는 문서 command 완료 순서와 독립적으로 흔들릴 수 있다.
- 입력 UX에서는 text input connection 상태뿐 아니라 “아직 처리 중인 입력 command”도 세션 상태로 봐야 한다.
- 큰 문서 편집기는 즉시 반영, pending overlay, SVG refresh를 분리해야 입력 지연과 깜빡임을 줄일 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reholds text refresh when focus returns after slow commit"`
