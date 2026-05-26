# 2026-05-26 native editor desktop input focus restore

## 작업한 내용

- macOS, Windows, Linux에서 텍스트 입력 직후 늦게 들어오는 `TextInputAction.done` 또는 connection close를 실제 편집 종료로 보지 않도록 했다.
- 해당 이벤트가 desktop input churn으로 판단되면 `RhwpNativeEditor`가 editor focus와 `TextInputConnection`을 다시 붙이고, deferred page refresh를 계속 보류한다.
- 외부 입력 필드로 실제 focus가 이동한 경우에는 기존처럼 deferred refresh가 진행되도록 위젯 테스트로 검증했다.

## 이 작업을 진행한 이유

큰 HWP 문서에서는 글자나 스페이스 하나를 입력한 뒤 페이지 SVG를 다시 렌더링하면 화면이 refresh되는 것처럼 보인다. 기존 debounce는 짧은 focus 흔들림은 막았지만, 데스크톱 TextInput 이벤트가 늦게 도착하면서 editor focus가 풀린 상태가 되면 refresh가 다시 열릴 수 있었다.

입력 commit은 Rust 문서에 즉시 반영하되, 사용자가 계속 편집 중인 동안에는 Flutter pending text overlay로 화면을 유지하고 무거운 SVG 동기화는 실제 focus 이동 뒤로 미루는 편이 예제 앱 사용감에 맞다.

## 이 작업을 통해 배울 점

- 데스크톱 Flutter의 TextInput action/connection 이벤트는 실제 사용자의 blur 의도와 다를 수 있다.
- 문서 편집기에서는 입력 이벤트와 렌더 동기화를 분리하고, focus churn을 별도 상태로 다뤄야 한다.
- 테스트는 “입력 churn은 refresh를 막고, 외부 focus 이동은 refresh를 허용한다”는 두 조건을 같이 검증해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor restores desktop text input after delayed churn action"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor holds text refresh across desktop input connection churn"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor ignores delayed desktop text input action while focused"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor waits for text input action before refresh"`
