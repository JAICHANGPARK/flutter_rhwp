# 2026-06-06 native editor table cell reference insertion

## 작업한 내용

- `RhwpDocument.insertHyperlinkInTableCell(...)`를 추가했다.
- `RhwpDocument.insertHiddenCommentInTableCell(...)`를 추가했다.
- Rust command envelope에 `insertHyperlinkInTableCell`,
  `insertHiddenCommentInTableCell`을 추가했다.
- vendored rhwp core의 본문 하이퍼링크/숨은 주석 삽입 로직을 문단 단위 helper로
  분리하고, 표 셀 내부 문단에도 같은 field/control 구조를 삽입하도록 연결했다.
- `RhwpNativeEditor` 입력 리본에서 활성 표 셀 텍스트 caret이 있을 때
  하이퍼링크와 숨은 주석 삽입 버튼을 활성화했다.
- 표 전체/셀 블록 선택 상태에서는 기존처럼 삽입 버튼을 비활성화해 context가
  불명확한 command 실행을 막았다.
- `README.md`, `CHANGELOG.md`, `docs/API_SPEC.md`,
  `docs/NATIVE_EDITOR_PARITY.md`, `docs/TODO.md`를 갱신했다.

## 이 작업을 진행한 이유

본문에서는 하이퍼링크와 숨은 주석 삽입이 가능했지만, 표 셀 안에서 텍스트를
편집하는 동안에는 입력 리본 버튼이 비활성화되어 있었다. 실제 문서 작성에서는
표 셀 안에도 링크나 검토용 주석을 넣는 흐름이 필요하므로, body-only 기능으로
남기면 Flutter-native editor가 upstream editor 경험을 대체하기 어렵다.

표 셀 텍스트 편집은 이미 `insertTextInTableCell` 좌표 체계를 갖고 있으므로,
새 API도 같은 `section`, `paragraph`, `controlIndex`, `cellIndex`,
`cellParagraph`, `offset` 형식을 따르게 했다. 이렇게 하면 앱 개발자가 자체
툴바를 만들 때도 표 셀 기능만 별도 좌표 모델로 이해할 필요가 없다.

## 이 작업을 통해 배울 점

- Flutter-native editor의 body cursor와 table-cell caret은 서로 다른 context다.
  같은 리본 버튼이라도 현재 context에 따라 다른 `RhwpDocument` API를 호출해야
  한다.
- 하이퍼링크는 단순 텍스트가 아니라 `Field` control과 `field_ranges`를 함께
  만들어야 한다. 표 셀 내부에서도 같은 구조를 유지해야 이후 field 조회/삭제와
  저장 경로를 확장할 수 있다.
- 숨은 주석은 보이는 텍스트를 삽입하지 않지만 `HiddenComment` control과 control
  gap이 필요하다. 따라서 본문과 표 셀 모두 paragraph-level helper를 공유하는
  편이 안전하다.
- 구현 완료와 round-trip 검증은 분리해서 추적해야 한다. 이번 작업은 표 셀 내부
  삽입 API와 editor 흐름을 열었고, HWPX field serialization round-trip 검증은
  별도 TODO로 남겼다.

## 검증

- `flutter test test/flutter_rhwp_test.dart --plain-name "table cell commands serialize to Rust envelopes"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts hyperlinks and comments in table cell text"`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
