# 2026-05-26 native editor late text input action refresh

## 작업한 내용

- 데스크톱 `TextInputAction` 또는 connection close가 늦게 도착해도 pending text overlay가 남아 있으면 native editor의 예약된 page refresh를 다시 보류하도록 했다.
- 외부 `TextField`처럼 실제 다른 focus가 잡힌 경우에는 refresh 보류를 해제해서 문서 렌더 동기화가 정상 진행되도록 분기했다.
- 늦은 desktop input action이 이미 걸린 refresh timer를 취소하고 editor input connection을 복구하는 위젯 회귀 테스트를 추가했다.

## 이 작업을 진행한 이유

macOS 예제 앱에서 스페이스나 텍스트 입력 뒤 데스크톱 입력 action이 늦게 들어오면, 사용자가 아직 편집 중인데도 SVG page refresh가 예약될 수 있었다. 204쪽 HWP 같은 큰 문서에서는 이 동기화가 입력할 때마다 화면이 refresh되는 것처럼 보인다.

문서 명령은 즉시 Rust core에 반영하되, 화면 동기화는 실제 외부 focus 이동 뒤로 미뤄야 native editor 입력감이 안정적이다.

## 이 작업을 통해 배울 점

- 데스크톱 Flutter의 `TextInputAction.done`은 사용자의 명시적 편집 종료가 아니라 입력 시스템 churn일 수 있다.
- pending overlay가 남아 있는 동안에는 document state와 rendered SVG state를 분리해서 다뤄야 한다.
- 외부 focus 여부를 같이 확인해야 입력 churn은 막고 실제 blur는 허용할 수 있다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor cancels scheduled refresh on late desktop input action"`은 현재 샌드박스가 `127.0.0.1` 테스트 소켓 생성을 막아 실행하지 못했다.
