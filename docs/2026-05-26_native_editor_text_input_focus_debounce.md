# 2026-05-26 Native Editor Text Input Focus Debounce

## 작업한 내용

- Flutter-native editor에서 데스크톱 TextInput 포커스 churn이 발생해도 focus-release 타이머가 살아 있는 동안 deferred page refresh를 해제하지 않도록 수정했다.
- `editRefreshDelay`가 기본 포커스 해제 지연보다 길면 데스크톱 TextInput focus-release debounce도 같은 지연을 따르도록 했다. 예제 앱처럼 `editRefreshDelay`를 길게 둔 경우 Space나 일반 텍스트 입력 직후 페이지 SVG가 다시 렌더링되는 현상을 줄인다.
- macOS TextInput 연결이 입력 직후 닫히고 포커스가 잠깐 사라져도 commit hold window 이후 즉시 refresh되지 않는 위젯 테스트를 추가했다.
- `CHANGELOG.md`에 입력 중 visible refresh churn 완화 내용을 반영했다.

## 이 작업을 진행한 이유

예제 앱에서 Space 또는 텍스트 입력 때마다 화면이 refresh되는 것처럼 보이면 실제 편집기 사용감이 크게 떨어진다. 텍스트 입력은 Rust 문서 모델에는 즉시 반영하되, 화면에서는 Flutter overlay로 먼저 보여주고 무거운 SVG 재렌더는 입력 흐름이 안정된 뒤로 미뤄야 한다.

## 이 작업을 통해 배울 점

- Flutter 데스크톱 TextInput은 입력 중 `performAction`, `connectionClosed`, focus lost가 짧은 간격으로 들어올 수 있다.
- 입력 command 완료 여부만 보면 부족하고, 포커스 해제 debounce와 연결 종료 debounce도 같은 pending refresh 상태를 공유해야 한다.
- 문서 모델 업데이트와 페이지 렌더 동기화는 분리해야 한다. 모델은 바로 저장/export 가능해야 하지만, 렌더는 사용자가 입력 중임을 우선해서 늦출 수 있어야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor debounces desktop focus churn with edit refresh delay"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor ignores delayed desktop text input action while focused"`
- `flutter analyze`
