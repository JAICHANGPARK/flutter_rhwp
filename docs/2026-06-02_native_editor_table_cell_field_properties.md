# Native editor table-cell field properties

## 작업한 내용

- Flutter-native editor의 table-cell context menu에서 `누름틀 속성`을 실행했을 때 table-cell cursor 기준 field inspection이 사용되는지 검증했다.
- `getFieldInfoAtInTableCell`로 cell 내부 field를 찾고, `getClickHereProperties`와 `updateClickHereProperties`로 ClickHere field 속성을 수정하는 흐름을 widget test로 고정했다.
- 속성 변경값으로 guide, memo, name, editable flag가 Rust command envelope에 그대로 전달되는지 확인했다.
- CHANGELOG에 table-cell field property 편집 보강 내용을 기록했다.

## 이 작업을 진행한 이유

표 셀 안의 누름틀은 body cursor와 다른 command envelope를 사용한다. Flutter-native editor가 WebView fallback 없이 실제 HWP 편집기로 쓰이려면 본문 field뿐 아니라 표 셀 내부 field도 같은 context-menu UX에서 안정적으로 편집되어야 한다.

## 이 작업을 통해 배울점

- Body field 검증만으로는 table-cell field 편집을 증명할 수 없다. Cell index, cell paragraph, active offset, text-box 여부가 command envelope에 포함되어야 한다.
- Flutter context menu에서 보이는 액션은 실제 cursor domain별 command path까지 테스트해야 한다.
- 기존 field dialog를 재사용해도, 호출 전 field inspection command가 body용인지 table-cell용인지가 핵심 차이다.

## 검증

- `dart format test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor context menu edits table cell field properties"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
