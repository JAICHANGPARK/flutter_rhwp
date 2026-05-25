# Native Editor Text Input Action Hold

## 작업한 내용

- Flutter-native editor에서 텍스트 commit 직후 들어오는 `TextInputAction`을 짧은 시간 동안 무시하도록 했다.
- 스페이스나 일반 텍스트 입력 직후 IME/데스크톱 입력 연결이 보내는 action이 deferred page refresh를 바로 풀지 않게 막았다.
- 즉시 action이 들어와도 pending text overlay를 유지하고, 사용자가 나중에 명시적으로 입력 action을 끝내면 페이지 SVG를 갱신하도록 widget test를 추가했다.

## 이 작업을 진행한 이유

- 예제 앱에서 스페이스나 글자를 입력할 때마다 렌더된 페이지가 refresh되어 에디터처럼 연속 입력하기 어렵다는 문제가 있었다.
- 현재 native editor는 Rust 문서 상태를 먼저 갱신하고 SVG 렌더링을 나중에 동기화하는 구조라서, 입력 중에는 무거운 page render를 최대한 늦춰야 한다.

## 이 작업을 통해 배울 점

- 데스크톱/IME 입력은 텍스트 commit과 별개로 action 또는 connection 이벤트를 보낼 수 있으므로, 이를 사용자 의도와 동일하게 처리하면 편집 화면이 과하게 갱신된다.
- 문서 mutation과 화면 렌더 동기화를 분리하면 Rust core 기반 편집에서도 입력 응답성을 단계적으로 개선할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor ignores immediate text input action after commit"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor waits for text input action before refresh"`
- `flutter test test/rhwp_widget_test.dart`
- `flutter analyze`
