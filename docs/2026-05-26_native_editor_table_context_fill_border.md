# 2026-05-26 Native Editor Table Context Fill Border

## 작업한 내용

- Flutter-native editor 표 셀 context menu에 `셀 노랑 채우기`, `셀 채우기 제거`, `셀 테두리` 항목을 추가했다.
- context menu action enum과 switch를 확장해 기존 `_applyTableCellStyle` command 경로를 재사용했다.
- 표 셀 context menu widget 테스트에서 채우기 항목 노출과 `applyTableCellStyle` fill command 실행을 검증했다.
- README와 CHANGELOG에 표 셀 context menu 채우기/테두리 지원 내용을 반영했다.

## 이 작업을 진행한 이유

셀 배경과 테두리는 표 편집에서 자주 쓰는 동작이다. 리본으로만 접근하면 셀을 선택한 뒤 탭과 버튼을 다시 찾아야 하므로, 우클릭 메뉴에서 바로 실행할 수 있게 해 Flutter-native editor를 실제 편집 흐름에 더 가깝게 만들었다.

## 이 작업을 통해 배울점

- 표 스타일 명령은 리본 전용 기능으로 두기보다 셀 선택 context menu에도 노출해야 반복 편집이 빠르다.
- 기존 command 경로를 재사용하면 기능 추가가 UI 진입점 확장에 집중되고 Rust bridge 변경을 줄일 수 있다.
- Web editor 포팅은 command coverage뿐 아니라 사용자가 명령을 발견하고 실행하는 위치까지 맞춰 가는 작업이다.
