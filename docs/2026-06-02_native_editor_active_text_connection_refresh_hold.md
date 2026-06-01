# 2026-06-02 native editor active text connection refresh hold

## 작업한 내용

- Flutter-native editor의 데스크톱 text input focus 판정을 보강했다.
- pending text overlay가 남아 있고 editor의 `TextInputConnection`이 아직 active이면, 일시적인 외부 focus를 입력 churn으로 처리하도록 했다.
- 긴 `editRefreshDelay`에서 external-focus release timer가 text connection close보다 먼저 실행되어도 page refresh가 풀리지 않는 회귀 테스트를 추가했다.

## 이 작업을 진행한 이유

예제 앱에서 스페이스나 텍스트를 입력할 때마다 페이지가 refresh되는 것처럼 보이는 문제는 대부분 text input 과정의 focus churn과 관련된다. 이전 보강은 `null` focus와 delayed action을 처리했지만, 실제 데스크톱 입력에서는 Flutter tree 밖의 platform text input처럼 보이는 focus가 잠깐 잡힐 수 있다.

이때 editor의 text connection이 아직 살아 있으면 사용자는 계속 문서 안에 입력 중인 상태다. 따라서 pending overlay를 유지하고, connection이 닫히거나 실제 외부 focus로 이동한 뒤에만 무거운 SVG refresh를 풀어야 한다.

## 이 작업을 통해 배울점

- 데스크톱 text input은 focus, action, connection close 이벤트 순서가 항상 안정적이지 않다.
- `TextInputConnection`이 active인지는 사용자가 아직 editor 입력 흐름 안에 있는지 판단하는 중요한 신호다.
- Flutter-native editor에서는 Rust command 반영과 SVG 재렌더 시점을 분리해야 대형 HWP 문서의 입력 UX가 안정된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor keeps refresh held while desktop text connection is active"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor delays external focus refresh during desktop input churn"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor can hold desktop text refresh until external focus"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor ignores transient external focus while holding text refresh"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor keeps focused text refresh held after input action"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor queues rapid text input commits"`
- `flutter analyze`
- `git diff --check`
