# 2026-06-06 native editor hidden comment editing

## 작업한 내용

- `RhwpHiddenCommentHit` 모델을 추가했다.
- `RhwpCommand.hiddenCommentAt`, `RhwpDocument.hiddenCommentAt(...)`를 추가했다.
- `RhwpCommand.updateHiddenCommentAt`, `RhwpDocument.updateHiddenCommentAt(...)`를 추가했다.
- Rust facade의 `applyCommand`가 `hiddenCommentAt`, `updateHiddenCommentAt` JSON 명령을 받아 rhwp core로 전달하도록 확장했다.
- vendored rhwp core에 본문 caret 기준 숨은 주석 조회와 내용 교체 함수를 추가했다.
- `RhwpNativeEditor` 입력 리본에 숨은 주석 편집 버튼을 추가했다.
- 본문 context menu에 주석 편집 항목을 추가했다.
- 숨은 주석 dialog를 삽입/편집 공용으로 바꿔 기존 텍스트와 action label을 받을 수 있게 했다.
- Rust facade smoke test, Dart command serialization test, native editor widget test를 확장했다.

## 이 작업을 진행한 이유

숨은 주석은 삽입과 삭제뿐 아니라 기존 내용 수정이 가능해야 실제 문서 편집 기능으로 쓸 수 있다. WebView fallback을 유지하더라도 Flutter-native editor가 독립적인 편집 surface가 되려면 주석 control의 조회, 편집, 삭제가 모두 공개 Dart API와 리본 UI로 제공되어야 한다.

## 배울점

- 숨은 주석은 본문 텍스트가 아니라 `Control::HiddenComment` 내부 paragraph list에 텍스트를 가진다.
- caret 위치에서 control을 찾는 로직은 삭제와 편집이 공유할 수 있다.
- 이번 구현은 본문 caret 기준으로 동작한다. 표 셀 내부 주석 삽입/편집/삭제와 HWPX 저장 round-trip 검증은 별도 작업으로 남는다.
