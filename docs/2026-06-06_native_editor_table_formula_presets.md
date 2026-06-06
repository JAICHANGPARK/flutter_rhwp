# Native editor table formula presets

## 작업한 내용

- Flutter-native table ribbon에 선택 셀 합계, 평균, 곱 preset 버튼을 추가했다.
- 선택된 table-cell 범위를 A1 표기법으로 변환해 `=SUM(range)`, `=AVG(range)`, `=PRODUCT(range)` 계산식을 만든다.
- preset 버튼은 기존 `evaluateTableFormula` command path를 그대로 사용하며, 계산 결과는 active table cell에 기록된다.
- preset 실행 시 formula text field도 생성된 수식으로 갱신해 사용자가 실행된 수식을 확인할 수 있게 했다.
- widget test에서 D2:E3 선택 범위가 `SUM`, `AVG`, `PRODUCT` command payload로 직렬화되는지 검증했다.
- `CHANGELOG.md`, `docs/TODO.md`, `docs/API_SPEC.md`, `docs/NATIVE_EDITOR_PARITY.md`에 반영했다.

## 이 작업을 진행한 이유

upstream Web editor의 표 메뉴에는 블록 계산식과 합계/평균/곱 단축 명령이 있다. Flutter-native editor는 이미 직접 수식 입력과 `evaluateTableFormula` command를 지원하고 있었지만, preset 버튼이 없어 parity 문서에서는 부분 구현으로 남아 있었다.

이번 작업은 Rust core를 새로 확장하지 않고 기존 formula evaluator가 지원하는 `SUM`, `AVG`, `PRODUCT` 함수를 Flutter 리본에 연결해 표 편집 경험을 한 단계 더 upstream에 맞춘 것이다.

## 이 작업을 통해 배울점

- Flutter selection row/column은 0-based이고 formula parser의 셀 참조는 A1/1-based 표기법이므로 변환 helper가 필요하다.
- table formula preset은 새 command가 아니라 기존 `evaluateTableFormula` command의 입력을 안정적으로 생성하는 UI 기능이다.
- preset 버튼을 직접 실행하더라도 formula field를 같이 갱신하면 사용자가 command 결과와 입력식을 추적하기 쉽다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor evaluates table formula presets"
flutter analyze
```
