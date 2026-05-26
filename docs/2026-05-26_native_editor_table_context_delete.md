# 2026-05-26 Native Editor Table Context Delete

## 작업한 내용

- Flutter-native editor 표 셀 context menu에 `줄 삭제`와 `칸 삭제` 항목을 추가했다.
- context menu action enum과 switch 처리를 확장해 기존 `_deleteTableRow` / `_deleteTableColumn` command 경로를 재사용했다.
- 표 셀 context menu widget 테스트에서 삭제 항목 노출과 `deleteTableRow` command 실행을 검증했다.
- README와 CHANGELOG에 표 context menu 삭제 지원 내용을 반영했다.

## 이 작업을 진행한 이유

표 편집은 리본 버튼만으로도 가능하지만, 실제 편집기에서는 셀을 우클릭한 자리에서 줄/칸 삽입과 삭제를 바로 실행하는 흐름이 중요하다. upstream 웹 에디터와 사용성을 맞추기 위해 삽입 방향 메뉴에 이어 삭제 동작도 같은 context menu에 노출했다.

## 이 작업을 통해 배울점

- context menu는 리본 기능의 보조가 아니라 편집 위치 기반 워크플로우의 핵심 진입점이다.
- 이미 구현된 command를 context menu에 연결하면 새 Rust API 없이도 Flutter-native editor의 실사용성이 올라간다.
- Flutter-native 포팅에서는 화면 기능과 마우스 중심 접근 경로를 함께 맞춰야 WebView fallback에 가까운 편집 경험이 된다.
