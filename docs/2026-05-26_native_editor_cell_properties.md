# 2026-05-26 Native Editor Cell Properties

## 작업한 내용

- `RhwpCellProperties` 모델과 `getCellProperties` / `setCellProperties` Dart command wrapper를 추가했다.
- Rust facade에서 rhwp core의 `get_cell_properties` / `set_cell_properties`를 Flutter 명령 envelope로 연결했다.
- Flutter-native 표 리본과 셀 context menu에서 선택된 셀의 폭, 높이, 안 여백, 세로 정렬, 글자 방향, 제목 셀, 보호 셀 값을 수정할 수 있는 다이얼로그를 추가했다.
- Dart command/document wrapper, native editor widget, Rust facade 테스트를 보강했다.

## 이 작업을 진행한 이유

표 편집은 행/열/병합/분할만으로는 실제 문서 편집에 부족하다. upstream rhwp core에는 선택 셀 속성 API가 이미 있으므로, Flutter-native editor에서도 Web editor에 가까운 표 편집 경험을 만들기 위해 해당 속성 편집을 직접 노출했다.

## 이 작업을 통해 배울점

- Rust core에 이미 있는 기능도 Flutter plugin API, editor state, 리본 UI, 테스트까지 이어야 실제 사용 가능한 기능이 된다.
- 표 전체 속성과 셀 단위 속성은 command 대상이 다르므로 `controlIndex`와 `cellIndex`를 명확히 분리해야 한다.
- Flutter-native editor 포팅은 화면을 닮게 만드는 작업보다 문서 모델의 command 단위를 안정적으로 노출하는 작업이 더 중요하다.
