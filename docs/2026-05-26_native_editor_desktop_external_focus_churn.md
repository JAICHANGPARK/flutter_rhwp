# 2026-05-26 native editor desktop external focus churn

## 작업한 내용

- Flutter-native editor의 데스크톱 텍스트 입력 commit 직후, 잠깐 외부 primary focus로 보이는 상태를 입력 churn으로 처리했다.
- `TextInputAction.done`, connection close, delayed focus change가 commit hold window 안에서 들어오면 deferred page refresh를 즉시 풀지 않도록 했다.
- 실제 외부 focus로 이동한 경우에는 hold window 이후 기존처럼 page refresh가 풀리도록 유지했다.
- 외부 focus churn을 재현하는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

macOS 데스크톱 예제에서 스페이스나 문자를 입력할 때마다 페이지가 다시 렌더되는 것처럼 보이는 경로가 남아 있었다. Flutter desktop 입력에서는 문자 commit 직후 platform text input이 짧게 닫히거나 primary focus가 외부로 보일 수 있다.

사용자는 계속 문서에 입력 중이므로, 이 짧은 churn을 편집 종료로 해석하면 큰 HWP 문서에서 글자 하나마다 SVG page refresh가 발생한다. 따라서 commit hold window 동안은 입력 세션의 일부로 흡수하고, 실제 외부 focus 이동만 refresh release로 처리한다.

## 이 작업을 통해 배울 점

- Flutter desktop의 primary focus 상태는 텍스트 입력 commit 중 일시적으로 흔들릴 수 있다.
- 문서 편집기에서는 Rust 문서 모델 반영과 SVG page refresh를 분리해야 입력 UX가 안정된다.
- 외부 focus 이동까지 막으면 안 되므로, churn 흡수는 commit hold window 안으로 제한하는 편이 안전하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor absorbs external focus churn during desktop text commit"`
