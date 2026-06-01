# Flutter-native editor desktop focus churn

## 작업한 내용

- desktop `TextInputConnection.close` 직후 외부 focus가 들어오는 짧은 구간을 별도 churn window로 분리했다.
- 지연된 `TextInputAction.done`, connection close, transient focus loss, 명시적인 외부 focus 이동을 서로 다른 release 조건으로 처리하도록 정리했다.
- `holdTextRefreshWhileFocused: false`를 지정한 경우에는 기존 debounce 동작을 유지하도록 테스트를 명시했다.

## 이 작업을 진행한 이유

Flutter desktop에서는 Space나 한글 IME 입력 뒤에 text input action, connection close, focus 변경 이벤트가 실제 사용자 의도와 다른 순서로 들어올 수 있다. 이 이벤트를 모두 같은 "편집 종료"로 보면 큰 HWP 문서에서 매 입력마다 page SVG refresh가 풀리고, 반대로 모두 churn으로 보면 외부 필드로 이동해도 refresh가 끝나지 않는다.

Flutter-native editor가 WebView 없이 실사용 가능한 편집기가 되려면 입력 중 overlay는 안정적으로 유지하면서도 실제 editor 이탈 시점에는 문서 렌더가 동기화되어야 한다.

## 이 작업을 통해 배울점

- desktop text input의 connection close는 바로 editor 이탈을 의미하지 않는다.
- delayed action은 이미 잡힌 refresh timer를 다시 hold할 수 있어야 한다.
- explicit external focus는 오래 붙어 있는 editor TextInputConnection보다 더 강한 이탈 신호로 봐야 한다.
- `holdTextRefreshWhileFocused` 기본값과 opt-out debounce 동작은 테스트에서 분리해서 검증해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --name "desktop"`
- `flutter test test/rhwp_widget_test.dart --name "text input"`
- `flutter test test/widget_test.dart` (`example/`에서 실행)
- `flutter analyze`
