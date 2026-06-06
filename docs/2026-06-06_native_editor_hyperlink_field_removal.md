# 2026-06-06 native editor hyperlink field removal

## 작업한 내용

- `fieldInfoAt(...)`이 ClickHere뿐 아니라 hyperlink field도 반환하도록 rhwp core field inspection을 확장했다.
- `removeFieldAt(...)`과 `removeFieldAtInTableCell(...)`이 ClickHere로 제한되지 않고 커서 위치의 일반 field marker를 제거하도록 변경했다.
- field marker 제거 시 표시 텍스트는 유지하고, 연결된 `Control::Field`, `FieldRange`, `ctrl_data_records`, 다른 field range의 control index, inline control gap을 함께 정리한다.
- `RhwpNativeEditor`의 누름틀 속성 dialog는 `fieldType == clickhere`일 때만 `clickHereProperties(...)`를 호출하도록 보호했다.
- Rust facade smoke test에서 하이퍼링크 field 조회와 제거 후 field list 미노출을 검증했다.
- widget test에서 hyperlink field에서 누름틀 속성 API가 호출되지 않는지 검증했다.

## 이 작업을 진행한 이유

하이퍼링크 삽입만 있으면 사용자가 잘못 넣은 링크를 Flutter-native editor에서 되돌릴 수 없다. upstream Web editor를 Flutter 위젯으로 대체하려면 field 계열 기능도 삽입, 조회, 제거가 같은 command 체계로 움직여야 한다. 또한 ClickHere 전용 속성 편집과 hyperlink 같은 일반 field 제거가 섞이면 잘못된 API 호출이 생기므로 두 흐름을 분리했다.

## 배울점

- HWP field 제거는 텍스트 삭제가 아니라 field marker 제거다. 표시 텍스트를 유지하려면 `FieldRange`만 삭제하는 것보다 연결된 field control과 UTF-16 inline gap도 같이 보정해야 한다.
- `fieldInfoAt(...)`은 사용자가 자체 툴바를 만들 때 분기 기준이 되는 API이므로, field type을 정확히 돌려주는 것이 중요하다.
- 이번 작업은 hyperlink field marker 삭제까지 구현했다. 하이퍼링크 URL/표시 텍스트 편집, 주석 삭제/편집, 표 셀 내부 삽입, HWPX field serialization round-trip은 후속 작업으로 남는다.
