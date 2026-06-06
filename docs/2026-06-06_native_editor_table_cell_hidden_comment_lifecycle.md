# 2026-06-06 native editor table cell hidden comment lifecycle

## 작업한 내용

- `RhwpDocument.hiddenCommentAtInTableCell(...)`를 추가했다.
- `RhwpDocument.updateHiddenCommentAtInTableCell(...)`를 추가했다.
- `RhwpDocument.deleteHiddenCommentAtInTableCell(...)`를 추가했다.
- Rust command envelope에 `hiddenCommentAtInTableCell`,
  `updateHiddenCommentAtInTableCell`, `deleteHiddenCommentAtInTableCell`을
  추가했다.
- vendored rhwp core에서 표 셀 내부 문단의 `HiddenComment` control을 조회,
  수정, 삭제하는 native command를 추가했다.
- `RhwpNativeEditor` 입력 리본과 context menu에서 활성 표 셀 텍스트 caret일 때
  숨은 주석 편집/삭제 버튼을 사용할 수 있게 했다.
- 표 전체 또는 셀 블록 선택 상태에서는 숨은 주석 편집/삭제 버튼을 계속
  비활성화했다.
- `README.md`, `CHANGELOG.md`, `docs/API_SPEC.md`,
  `docs/NATIVE_EDITOR_PARITY.md`, `docs/TODO.md`를 갱신했다.

## 이 작업을 진행한 이유

직전 작업에서 표 셀 내부에 숨은 주석을 삽입할 수 있게 되었지만, 삽입된 주석을
표 셀 안에서 다시 읽거나 수정하거나 삭제하는 API는 없었다. 이 상태로는 실제
문서 작성 흐름에서 “주석을 넣은 뒤 고치는” 기본 동작이 끊긴다.

본문 주석 lifecycle과 표 셀 주석 lifecycle을 같은 수준으로 맞추면 Flutter-native
editor가 WebView full editor를 대체할 때 필요한 입력 기능의 완성도가 올라간다.
또한 외부 앱이 자체 툴바를 만들 때 body/table-cell context만 구분하면 같은
방식으로 숨은 주석 기능을 호출할 수 있다.

## 이 작업을 통해 배울 점

- 표 셀 내부 command는 body command와 같은 사용자 기능이라도 좌표가 다르다.
  `section`, `paragraph`, `controlIndex`, `cellIndex`, `cellParagraph`, `offset`
  모두 필요하다.
- 숨은 주석 삭제는 control 제거뿐 아니라 `ctrl_data_records`, field range의
  control index, control gap, paragraph control mask를 함께 갱신해야 한다.
- 리본 버튼은 기능 존재 여부만으로 활성화하면 안 된다. 표 셀 block selection과
  표 셀 text caret은 서로 다른 편집 context이므로, 버튼 활성 조건을 분리해야
  한다.
- 이번 작업은 표 셀 내부 주석 lifecycle을 API/UI/test로 연결했지만, HWPX 저장
  후 다시 열었을 때 같은 field/control 구조가 보존되는 round-trip 검증은 별도
  작업으로 남아 있다.

## 검증

- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart --plain-name "table cell commands serialize to Rust envelopes"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts hyperlinks and comments in table cell text"`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
