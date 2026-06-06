# 2026-06-06 native editor hyperlink editing

## 작업한 내용

- `RhwpCommand.updateHyperlink`와 `RhwpDocument.updateHyperlink(...)`를 추가했다.
- Rust facade의 `applyCommand`가 `updateHyperlink` JSON 명령을 받아 rhwp core로 전달하도록 확장했다.
- vendored rhwp core에 hyperlink field id 기준 URL command와 표시 텍스트를 함께 갱신하는 `update_hyperlink_native`를 추가했다.
- `RhwpNativeEditor` 도구 리본에 하이퍼링크 편집 버튼을 추가했다.
- 본문/표 셀 context menu에 하이퍼링크 편집 항목을 추가했다.
- 기존 하이퍼링크 dialog를 삽입/편집 공용으로 바꿔 초기 URL, 표시 텍스트, action label을 받을 수 있게 했다.
- Rust facade smoke test에서 하이퍼링크 편집 후 field list의 URL command와 표시 텍스트가 바뀌는지 검증했다.
- widget test와 Dart command serialization test로 Flutter-native editor와 공개 Dart API 계약을 고정했다.

## 이 작업을 진행한 이유

하이퍼링크 삽입과 field marker 삭제만으로는 실제 문서 편집 흐름이 부족하다. 사용자는 잘못된 URL이나 표시 텍스트를 수정할 수 있어야 하고, 패키지 사용자는 자체 툴바에서 같은 기능을 직접 호출할 수 있어야 한다. 그래서 URL command와 field range 표시 텍스트를 동시에 갱신하는 공개 API를 추가했다.

## 배울점

- HWP hyperlink는 표시 텍스트와 URL이 서로 다른 위치에 저장된다. 표시 텍스트는 field range 안의 paragraph text이고, URL은 `Control::Field.command`이다.
- 일반 `setFieldValue(...)`는 표시 텍스트만 바꿀 수 있으므로 hyperlink 편집에는 전용 command가 필요하다.
- Flutter-native editor의 field UI는 field type별로 분기해야 한다. ClickHere 속성 편집과 hyperlink 편집은 같은 field inspection API를 쓰지만 서로 다른 command를 호출한다.
- 이번 작업은 body/table-cell caret에서 field id를 찾는 UI 경로를 열어두었다. 표 셀 내부 hyperlink 삽입과 HWPX field serialization round-trip 검증은 아직 남은 작업이다.
