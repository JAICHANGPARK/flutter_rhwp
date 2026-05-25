# 2026-05-25 native editor double click word selection

## 작업한 내용

- `RhwpNativeEditor` page overlay에서 primary pointer double-click을 감지한다.
- page layer tree의 text run hit-test 결과를 사용해 클릭한 단어의 source offset range를 계산한다.
- 계산된 단어 범위를 `RhwpSelectionRange`로 반영해 Flutter-native selection overlay와 이후 copy/cut/format command가 같은 selection model을 쓰게 했다.
- 한국어 HWP 문서에서 단어 선택이 동작하도록 Hangul/CJK code unit을 word character로 처리했다.

## 이 작업을 진행한 이유

upstream 웹 에디터처럼 문서 편집기가 자연스럽게 느껴지려면 단순 클릭 caret 이동과 drag selection만으로는 부족하다. 더블클릭 단어 선택은 복사, 잘라내기, 서식 적용, 교체 같은 후속 편집의 시작점이므로 Flutter-native editor가 WebView fallback을 대체해 가는 데 필요한 기본 입력 UX다.

## 이 작업을 통해 배울 점

- Flutter-native editor의 선택 동작은 렌더된 SVG 자체가 아니라 page layer tree의 source 위치를 기준으로 만들어야 한다.
- 더블클릭처럼 문서를 수정하지 않는 UX는 Rust command를 호출하지 않고 controller selection state만 갱신하는 편이 맞다.
- 한국어 문서 편집기는 ASCII word boundary만으로는 부족하므로 Hangul/CJK 텍스트를 단어 문자로 다뤄야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor selects a word on double click"`
