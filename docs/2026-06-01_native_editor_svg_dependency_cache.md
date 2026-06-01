# 2026-06-01 native editor SVG dependency cache

## 작업한 내용

- `RhwpViewer`가 같은 SVG 문자열과 `svgBuilder`를 유지하는 동안 page SVG 위젯 캐시를 계속 재사용하도록 했다.
- text input, focus, `MediaQuery` 같은 inherited dependency 변화가 있어도 실제 page render revision이 바뀌지 않으면 SVG 본문 위젯을 다시 만들지 않게 했다.
- dependency churn 중에도 `svgBuilder`가 다시 호출되지 않는 widget test를 추가했다.
- CHANGELOG에 native editor 입력 중 SVG page surface 재생성 방지 내용을 반영했다.

## 이 작업을 진행한 이유

macOS 데스크톱 입력에서는 스페이스나 텍스트 commit 주변에서 focus, text input connection, `MediaQuery` 계층이 흔들릴 수 있다. Rust 렌더 호출을 막아도 Flutter SVG 위젯 캐시가 이 변화에 반응해 비워지면 같은 SVG를 다시 구성하게 되고, 사용자는 페이지가 refresh되는 것처럼 느낄 수 있다.

native editor는 문서 본문 SVG와 caret, selection, pending text overlay를 다른 갱신 주기로 다뤄야 한다. 문서 render revision이 바뀌지 않은 입력 중에는 SVG page surface를 그대로 두고 overlay만 바뀌는 편이 맞다.

## 이 작업을 통해 배울 점

- 렌더 호출 억제와 위젯 캐시 유지, repaint 분리는 각각 다른 문제다.
- 데스크톱 text input은 실제 문서 변경과 무관한 dependency churn을 만들 수 있으므로, 무거운 문서 surface의 캐시 무효화 기준을 명확히 해야 한다.
- Flutter-native editor에서는 page render revision을 명시적 동기화 신호로 삼고, 입력 중 시각 피드백은 overlay로 처리하는 구조가 안정적이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer keeps SVG widget cached across dependency churn"`
