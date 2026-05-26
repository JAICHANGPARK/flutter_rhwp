# 2026-05-26 Native Editor Table Context Vertical Align

## 작업한 내용

- Flutter-native editor 표 셀 context menu에 `셀 위쪽 정렬`, `셀 가운데 정렬`, `셀 아래쪽 정렬` 항목을 추가했다.
- context menu action enum과 switch를 확장해 기존 `_applyTableCellStyle(verticalAlign: ...)` command 경로를 재사용했다.
- 표 셀 context menu widget 테스트에서 세로 정렬 항목 노출과 `applyTableCellStyle` command 실행을 검증했다.
- README와 CHANGELOG에 표 셀 context menu 세로 정렬 지원 내용을 반영했다.

## 이 작업을 진행한 이유

셀 세로 정렬은 표 리본에만 있으면 리본 탭 전환이 필요하다. 실제 문서 편집에서는 선택한 셀을 우클릭해 셀 관련 동작을 바로 실행하는 흐름이 자연스럽기 때문에, 기존 리본 기능을 context menu에도 연결해 Flutter-native editor의 사용성을 Web editor에 더 가깝게 맞췄다.

## 이 작업을 통해 배울점

- 같은 command라도 리본과 context menu에 모두 노출되어야 편집 위치 기반 UI가 완성된다.
- Flutter-native editor는 새 기능을 만들 때보다 기존 command 경로를 여러 진입점에 안정적으로 연결하는 작업이 많다.
- 표 편집 UX는 셀 선택 상태를 유지한 채 command를 실행하고 다시 overlay를 갱신하는 흐름이 핵심이다.
