# 2026-06-06 native editor hidden comment deletion

## 작업한 내용

- `RhwpCommand.deleteHiddenCommentAt`와 `RhwpDocument.deleteHiddenCommentAt(...)`를 추가했다.
- Rust facade의 `applyCommand`가 `deleteHiddenCommentAt` JSON 명령을 받아 rhwp core로 전달하도록 확장했다.
- vendored rhwp core에 본문 caret 기준 숨은 주석 control 삭제 함수를 추가했다.
- 숨은 주석 삭제 시 `Control::HiddenComment`, `ctrl_data_records`, field range control index, inline control gap, control mask를 함께 정리한다.
- `RhwpNativeEditor` 입력 리본에 숨은 주석 삭제 버튼을 추가했다.
- 본문 context menu에도 주석 삭제 항목을 추가했다.
- Rust facade smoke test, Dart command serialization test, native editor widget test를 추가/확장했다.

## 이 작업을 진행한 이유

숨은 주석 삽입만 있으면 사용자가 잘못 넣은 주석을 Flutter-native editor에서 제거할 수 없다. WebView fallback을 유지하더라도 Flutter 위젯 editor를 실제 문서 편집 surface로 키우려면 Insert 메뉴 기능은 삽입과 삭제가 함께 제공되어야 한다.

## 배울점

- 숨은 주석은 하이퍼링크처럼 field range가 아니라 `Control::HiddenComment`로 저장된다.
- 삭제는 텍스트 삭제가 아니라 inline control 삭제이며, UTF-16 control gap을 보정해야 다음 렌더/직렬화 위치가 유지된다.
- 현재 구현은 본문 caret 기준 삭제다. 주석 내용 편집, 표 셀 내부 삽입/삭제, HWPX 저장 round-trip 검증은 후속 작업으로 남는다.
