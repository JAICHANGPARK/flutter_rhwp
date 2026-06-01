# Flutter-native editor field values

## 작업한 내용

- `RhwpFieldInfo`와 `RhwpCommand.getFieldList/getFieldValue/getFieldValueByName/setFieldValue/setFieldValueByName`을 추가했다.
- Rust `applyCommand`에서 vendored rhwp의 `get_field_list`, `get_field_value`, `get_field_value_by_name_api`, `set_field_value`, `set_field_value_by_name_api`로 연결했다.
- `RhwpDocument.fields`, `fieldValue`, `fieldValueByName`, `setFieldValue`, `setFieldValueByName` convenience API를 추가했다.
- `RhwpNativeEditor` 도구 리본에 필드 값 대화상자를 추가해 누름틀/필드 목록을 조회하고 값을 수정할 수 있게 했다.
- Dart command/API 테스트, Flutter widget 테스트, Rust facade smoke test를 추가했다.
- `README.md`와 `CHANGELOG.md`에 필드 값 편집 기능을 반영했다.

## 이 작업을 진행한 이유

WebView 기반 full editor는 유지하되, 장기 목표는 rhwp 웹 에디터 기능을 Flutter 위젯으로 옮기는 것이다. HWP의 필드/누름틀은 실제 문서 작성 워크플로우에서 자주 쓰이는 편집 대상이므로, 단순 텍스트 입력을 넘어 문서 구조 API를 Flutter-native editor에서 다룰 수 있어야 한다.

이번 작업은 JS/WebView를 거치지 않고 Rust core API를 FRB 명령으로 직접 노출한다. 이렇게 하면 Android, iOS, macOS, Windows, Linux에서는 native Rust 라이브러리를, Web에서는 WASM 브리지를 쓰는 현재 구조와 맞게 기능을 확장할 수 있다.

## 이 작업을 통해 배울점

- upstream rhwp 웹 에디터에서 쓰는 문서 기능은 Flutter UI로 다시 만들더라도 Rust core를 source of truth로 유지하는 편이 안전하다.
- Flutter-native editor 기능을 늘릴 때는 Dart command envelope, Rust command enum, `RhwpDocument` convenience API, 리본 UI, 테스트를 한 단위로 묶어야 누락을 줄일 수 있다.
- 필드처럼 문서 구조에 걸친 기능은 커서 위치 기반 입력보다 전역 목록 조회와 식별자 기반 수정 API가 더 안정적이다.
- WebView fallback과 Flutter-native editor는 경쟁 구조가 아니라, full-feature fallback과 점진적 native surface로 병행하는 구조가 유지보수에 유리하다.
