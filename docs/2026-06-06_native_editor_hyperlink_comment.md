# 2026-06-06 native editor hyperlink comment

## 작업한 내용

- `RhwpCommand.insertHyperlink`와 `RhwpDocument.insertHyperlink(...)`를 추가했다.
- `RhwpCommand.insertHiddenComment`와 `RhwpDocument.insertHiddenComment(...)`를 추가했다.
- Rust facade의 `applyCommand`가 `insertHyperlink`, `insertHiddenComment` JSON 명령을 받아 rhwp core로 전달하도록 확장했다.
- vendored rhwp core에 본문 위치 기준 하이퍼링크 field 삽입과 숨은 주석 control 삽입 함수를 추가했다.
- `RhwpNativeEditor` 입력 리본에 하이퍼링크/주석 버튼과 입력 dialog를 추가했다.
- 선택 텍스트가 있는 상태에서 하이퍼링크를 삽입하면 선택 영역을 삭제하고 같은 위치에 표시 텍스트와 hyperlink field range를 만든다.
- widget test와 Rust facade smoke test로 command payload와 Rust 명령 수용 여부를 확인했다.

## 이 작업을 진행한 이유

upstream `rhwp` Web editor 경험을 100% Flutter-native editor로 옮기려면 단순 텍스트 입력뿐 아니라 문서 작성자가 자주 쓰는 참조/필드 계열 입력도 Flutter 리본에서 바로 동작해야 한다. 하이퍼링크와 주석은 사용자가 자체 툴바를 만들 때도 명확한 공개 API가 필요하므로, Flutter UI와 Dart API, Rust command path를 같은 작업 단위로 연결했다.

## 배울점

- Flutter-native editor 기능은 리본 버튼만 추가하면 끝나지 않고, Dart command, Rust facade, rhwp core mutation, 저장/렌더 invalidation이 함께 맞아야 한다.
- 하이퍼링크는 일반 텍스트 삽입과 다르게 `FieldRange`와 `Control::Field`의 인덱스가 같이 움직이므로 기존 field range와 control index 보정이 필요하다.
- 숨은 주석은 본문 텍스트가 아니라 control로 들어가므로 caret 위치의 inline control gap과 페이지 재조합 처리가 필요하다.
- 이번 작업은 삽입 경로까지 구현했다. 하이퍼링크/주석 편집, 삭제, 표 셀 내부 삽입, HWPX field serialization round-trip은 별도 작업으로 검증해야 한다.
