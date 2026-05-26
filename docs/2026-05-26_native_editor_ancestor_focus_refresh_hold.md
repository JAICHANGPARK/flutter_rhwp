# 2026-05-26 native editor ancestor focus refresh hold

## 작업한 내용

- 데스크톱 텍스트 입력 중 `FocusManager.primaryFocus`가 에디터의 루트나 상위 `FocusScope`로 잠깐 이동하는 경우를 외부 포커스로 보지 않도록 했다.
- Space나 일반 텍스트 입력 뒤 늦게 도착하는 `TextInputAction.done`이 deferred page refresh를 풀지 않고 입력 churn으로 처리되게 했다.
- ancestor focus 상태에서 delayed text input action이 와도 pending text overlay가 유지되고 SVG render가 실행되지 않는 위젯 테스트를 추가했다.
- `CHANGELOG.md`에 입력 중 refresh hold 정책을 반영했다.

## 이 작업을 진행한 이유

macOS 데스크톱 Flutter에서는 텍스트 입력 과정에서 실제 사용자가 다른 필드로 이동하지 않아도 primary focus가 에디터의 상위 focus scope로 흔들릴 수 있다. 기존 로직은 이 상태를 외부 포커스 이동으로 해석할 수 있었고, 그 결과 Space나 텍스트 입력 직후 deferred refresh가 풀리면서 페이지가 다시 렌더링되는 느낌을 만들 수 있었다.

에디터 내부 또는 상위 focus churn은 입력 세션의 일부로 보고, 실제 외부 위젯으로 포커스가 이동한 경우에만 refresh release를 허용하는 편이 문서 편집 UX에 맞다.

## 이 작업을 통해 배울 점

- 데스크톱 Flutter의 `primaryFocus`는 텍스트 입력 수명주기와 1:1로 안정적으로 맞지 않는다.
- 편집기에서는 focus node 동일성만 보지 말고 BuildContext 관계를 같이 봐야 내부 focus scope churn과 실제 외부 포커스 이동을 구분할 수 있다.
- SVG 기반 문서 편집에서는 입력 명령 적용, optimistic overlay, page SVG refresh release 시점을 분리해야 큰 문서에서도 입력이 안정적으로 보인다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor treats ancestor focus action as desktop input churn"`
- `flutter analyze`
