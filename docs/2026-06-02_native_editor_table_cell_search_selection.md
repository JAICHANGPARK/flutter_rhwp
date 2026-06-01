# 2026-06-02 native editor table cell search selection

## 작업한 내용

- Flutter-native editor에서 표 셀 내부 검색 결과가 실제 table-cell text selection으로 잡히도록 했다.
- 표 셀 검색 결과의 `selectionBaseOffset`은 match 시작점, `activeOffset`은 match 끝점으로 동기화한다.
- 표 셀 검색 결과를 교체한 뒤에도 본문 검색 교체처럼 새 replacement 범위가 선택 상태로 남도록 했다.
- 상태바의 입력 모드 표시가 본문 selection뿐 아니라 표 셀 내부 text selection도 `Selection`으로 표시하도록 보정했다.

## 이 작업을 진행한 이유

기존 표 셀 검색은 화면의 검색 하이라이트만 보이고 editor selection model은 match 시작점 caret으로 남았다. 이 상태에서는 본문 검색 결과와 표 셀 검색 결과의 후속 동작이 달라져, 교체 후 선택 상태나 상태바 표시가 실제 편집 컨텍스트를 제대로 반영하지 못했다.

Flutter-native editor가 WebView fallback 없이도 실제 편집기로 동작하려면 검색, 교체, 복사, 삭제, 입력이 모두 같은 selection model을 공유해야 한다.

## 이 작업을 통해 배울점

- 검색 하이라이트와 editor selection은 별개라서, 시각적으로 보인다고 편집 모델이 선택 상태라고 볼 수 없다.
- 본문 selection과 표 셀 selection은 타입은 다르지만, 검색/교체 이후의 UX는 같은 규칙으로 맞추는 편이 후속 편집 명령을 단순하게 만든다.
- 상태바처럼 작은 UI도 현재 편집 컨텍스트를 기준으로 판단해야 body-only 상태 표시가 표 셀 편집 경험을 깨지 않는다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "active table cell search match"`
- `flutter test test/rhwp_widget_test.dart --plain-name "search"`
- `flutter test test/rhwp_widget_test.dart --plain-name "status bar"`
- `flutter analyze`
- `git diff --check`
