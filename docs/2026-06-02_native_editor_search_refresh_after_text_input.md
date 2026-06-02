# 2026-06-02 native editor search refresh after text input

## 작업한 내용

- Flutter-native editor에서 deferred text-input refresh가 flush된 뒤 active search matches를 다시 계산하도록 했다.
- 검색 재계산은 caret/selection focus를 다시 선택하지 않고 search count와 highlight 상태만 갱신하도록 분리했다.
- 검색된 텍스트를 입력으로 대체한 뒤, 새 page layer tree 기준으로 `0 / 0` 검색 상태가 표시되는 widget test를 추가했다.
- `CHANGELOG.md`에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

Flutter-native editor는 Space/text 입력 중 page SVG refresh를 지연해 입력 표면을 안정화한다. 하지만 refresh가 끝난 뒤에도 검색 결과가 이전 layer tree에 남으면 search count와 highlight가 실제 문서 상태와 어긋난다. WebView editor fallback을 유지하더라도 Flutter 위젯 editor가 독립 surface가 되려면 입력, render, search overlay가 같은 문서 상태를 바라봐야 한다.

## 이 작업을 통해 배울점

- 입력 중 refresh 지연은 화면 깜빡임을 줄이지만, release 이후에는 search overlay 같은 파생 상태도 다시 동기화해야 한다.
- search command와 edit 후 search refresh는 focus 정책이 다르다. 사용자가 Find를 누른 경우에는 active match로 이동하지만, edit 후 자동 refresh는 editor caret를 훔치지 않아야 한다.
- fake session이 layer tree를 자동 변경하지 않는 테스트 환경에서는 command 이후 layer tree를 명시적으로 바꿔 core 문서 상태 변경을 모델링할 수 있다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor refreshes search matches after text input refresh"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
