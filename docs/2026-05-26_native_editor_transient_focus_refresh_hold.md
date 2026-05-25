# 2026-05-26 native editor transient focus refresh hold

## 작업한 내용

- 데스크톱 텍스트 입력 중 focus가 잠깐 빠졌다가 다시 editor로 돌아오는 경우, pending page refresh가 예약되지 않도록 했다.
- `_closeTextInput()`에서 desktop commit hold window가 살아 있는 동안에는 deferred refresh release를 실행하지 않고, hold timer가 실제 입력 종료 여부를 판단하도록 바꿨다.
- `_releaseDeferredEditRefreshFromTextInput()`이 macOS, Windows, Linux에서 editor focus나 active text input connection이 남아 있으면 refresh를 풀지 않도록 강화했다.
- focus가 1초가량 빠졌다가 돌아오는 회귀 테스트를 추가했다.

## 이 작업을 진행한 이유

예제 앱에서 스페이스나 텍스트를 입력할 때마다 문서 화면이 다시 그려지는 것처럼 보일 수 있었다. 원인은 입력 자체가 아니라 데스크톱 TextInput 연결과 focus 상태가 입력 중 짧게 흔들릴 때, 기존 코드가 hold window를 정리하면서 deferred page refresh를 풀 수 있었기 때문이다.

문서 모델 command는 즉시 적용하되, 사용자가 계속 입력 중이면 SVG 렌더 동기화는 보류해야 한다. 그래야 큰 HWP 문서에서 글자 하나를 입력할 때마다 전체 페이지가 깜빡이는 흐름을 줄일 수 있다.

## 이 작업을 통해 배울점

- Flutter desktop의 focus loss는 항상 사용자가 편집을 끝냈다는 뜻이 아니다. TextInput 연결 정리 과정에서도 transient focus loss가 발생할 수 있다.
- refresh release 조건은 commit hold, focus, text input connection을 함께 봐야 한다.
- native editor에서는 Rust 문서 상태와 Flutter overlay 표시, SVG page refresh를 분리해야 입력 UX가 안정된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor cancels transient desktop focus release when focus returns"`
