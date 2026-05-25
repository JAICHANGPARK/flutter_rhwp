# 2026-05-26 native editor SVG cache during input

## 작업한 내용

- `RhwpViewer`의 page SVG 본문 위젯을 SVG 문자열과 `svgBuilder` 기준으로 캐시했다.
- `RhwpNativeEditor` 입력 중 pending text overlay, caret, selection 같은 오버레이만 바뀌는 경우 기존 SVG 위젯을 재사용하도록 했다.
- overlay만 갱신될 때 `svgBuilder`가 다시 호출되지 않는 위젯 회귀 테스트를 추가했다.
- `CHANGELOG.md`에 입력 중 SVG 위젯 캐시 개선 내용을 반영했다.

## 이 작업을 진행한 이유

입력 refresh 보류 로직이 Rust 렌더 호출 자체는 막고 있었지만, 에디터 `setState`마다 `SvgPicture.string` 위젯이 새로 만들어질 수 있었다. 사용자가 스페이스나 텍스트를 입력할 때 pending overlay가 갱신되면서 SVG가 다시 파싱/페인트되는 것처럼 보여 문서가 refresh 되는 느낌을 만들었다.

입력 중에는 문서 본문 SVG보다 caret과 pending text overlay가 더 자주 바뀐다. 두 레이어를 분리해 본문 SVG는 재사용하고 오버레이만 갱신하는 편이 Flutter-native editor의 체감 안정성에 맞다.

## 이 작업을 통해 배울 점

- 렌더 Future를 다시 만들지 않아도, 무거운 child widget을 매 build마다 새로 만들면 사용자에게는 refresh처럼 보일 수 있다.
- 편집기 UI는 문서 본문, selection/caret, pending input을 서로 다른 갱신 주기로 다루는 구조가 필요하다.
- 위젯 캐시는 SVG 문자열, builder identity, dependency 변경 시점 같은 무효화 기준을 명확히 둬야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer keeps SVG widget cached during overlay updates"`
