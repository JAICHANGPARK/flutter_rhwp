# 2026-06-02 Native Editor Table Cell Text Style

## 작업한 내용

- Flutter-native 에디터에서 표 셀 내부 텍스트 선택 범위가 여러 cell paragraph를 포함할 때 스타일 적용 대상도 선택 범위 전체가 되도록 명시 검증했다.
- `_applyStyle`이 body/table style 적용 후 `_syncCurrentParaFormat()`을 호출하도록 보강했다.
- 선택된 셀 텍스트의 두 cell paragraph에 `applyCellStyle`이 각각 호출되는 widget test를 추가했다.

## 이 작업을 진행한 이유

- 이전 작업에서 문단 서식 대상 계산은 확장했지만, document style 적용 경로도 같은 대상 계산을 공유한다는 회귀 검증이 필요했다.
- 스타일 적용 후 현재 문단 속성 리본 상태가 stale 상태로 남지 않도록 동기화가 필요했다.

## 이 작업을 통해 배울점

- style은 paragraph-level 편집 명령이라서 셀 내부 text selection의 paragraph target 계산을 공유해야 한다.
- 편집 명령 실행 후 UI 리본 상태를 다시 동기화해야 native editor가 명령 적용 결과와 일치한다.
- helper를 공유하는 경로라도 명시 테스트를 추가해야 Flutter-native 포팅의 긴 회귀면을 줄일 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "selected table cell text paragraphs"`
- `flutter test test/rhwp_widget_test.dart --plain-name "document styles"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
