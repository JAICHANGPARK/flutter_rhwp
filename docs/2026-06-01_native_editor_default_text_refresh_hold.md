# Flutter-native editor default text refresh hold

## 작업한 내용

- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`의 `holdTextRefreshWhileFocused` 기본값을 `true`로 변경했다.
- desktop text input의 지연된 `TextInputAction.done` 이후 실제로 editor focus가 사라지면 보류된 page SVG refresh가 닫히도록 release 조건을 보강했다.
- README와 CHANGELOG에 기본 typing refresh hold 정책을 반영했다.

## 이 작업을 진행한 이유

첨부한 204쪽 HWP처럼 큰 문서에서는 Space나 텍스트 입력마다 SVG page refresh가 풀리면 화면이 매번 다시 그려지는 것처럼 보인다. Flutter-native editor는 Rust 문서 명령을 즉시 적용하되, 사용자가 아직 입력 중인 동안에는 Flutter overlay로 커밋된 텍스트와 caret을 유지하는 쪽이 더 안정적이다.

기존 옵션을 앱마다 직접 켜야 하면 예제 외부에서 같은 문제가 반복될 수 있으므로, native editor의 기본값을 큰 문서 편집에 맞췄다.

## 이 작업을 통해 배울점

- 문서 편집에서 데이터 커밋과 page render 동기화는 분리해야 한다.
- desktop text input은 `TextInputAction.done`, connection close, focus churn이 실제 입력 종료와 항상 같은 의미가 아니다.
- 기본값은 작은 데모보다 실제 HWP 문서 크기와 IME 입력 흐름에 맞춰 정하는 편이 낫다.

## 검증

- `flutter test test/rhwp_widget_test.dart --name "text input"`
- `flutter test test/widget_test.dart` (`example/`에서 실행)
- `flutter analyze`
