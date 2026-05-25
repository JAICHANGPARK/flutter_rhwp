# 2026-05-26 native editor desktop input connection churn

## 작업한 내용

- `RhwpNativeEditor`가 텍스트 입력 refresh 보류 여부를 판단할 때 `TextInputConnection.attached`뿐 아니라 에디터 포커스 상태도 함께 보도록 변경했다.
- 데스크톱 플랫폼에서 글자 입력 중 text input connection이 일시적으로 닫히더라도, 에디터에 포커스가 남아 있으면 페이지 SVG refresh를 해제하지 않도록 했다.
- connection이 닫혔지만 포커스가 유지되는 경우 text input connection을 다시 열어 다음 입력을 받을 수 있게 했다.
- 확정된 일반 텍스트 입력은 불필요하게 `_inputValue` 상태를 먼저 그리지 않고 바로 문서 명령 큐로 넘기도록 줄였다.
- 데스크톱 input connection churn 상황을 재현하는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

예제 앱에서 스페이스나 텍스트를 입력할 때마다 문서가 refresh 되는 것처럼 보이는 문제가 있었다. 이전 로직은 입력 connection이 살아 있는 동안 refresh를 보류했지만, 데스크톱 환경에서는 플랫폼 text input connection이 입력 중에도 닫혔다가 다시 열릴 수 있다.

사용자 입장에서는 포커스가 여전히 에디터에 있으므로 입력 세션이 계속되는 상태다. 따라서 connection 종료만으로 refresh를 시작하지 않고, 포커스 이탈이나 명시적인 입력 완료 action을 기준으로 refresh를 풀도록 조정했다.

## 이 작업을 통해 배울 점

- Flutter 데스크톱 text input connection의 생명주기와 실제 사용자 입력 세션은 항상 1:1로 맞지 않는다.
- 문서 편집기에서는 플랫폼 connection보다 에디터 포커스와 입력 action을 함께 봐야 타이핑 중 화면 깜빡임을 줄일 수 있다.
- Rust 문서 명령은 즉시 적용하되, 무거운 SVG 렌더 동기화는 별도 스케줄러로 늦추는 구조가 편집 UX에 더 적합하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor holds text refresh across desktop input connection churn"`
