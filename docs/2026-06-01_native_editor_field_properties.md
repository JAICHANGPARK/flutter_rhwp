# Flutter-native editor field properties

## 작업한 내용

- `RhwpFieldRangeInfo`와 `RhwpClickHereProperties` 모델을 추가했다.
- `getFieldInfoAt`, `getFieldInfoAtInTableCell`, `removeFieldAt`, `removeFieldAtInTableCell`, `getClickHereProperties`, `updateClickHereProperties` 명령을 Dart/Rust bridge에 추가했다.
- `RhwpDocument` convenience API로 커서 위치 필드 조회, 누름틀 속성 조회/수정, 필드 마커 제거를 사용할 수 있게 했다.
- `RhwpNativeEditor` 도구 리본의 필드 그룹에 `Field properties`와 `Remove field at cursor` 버튼을 추가했다.
- 누름틀 속성 다이얼로그에서 안내문, 메모, 필드 이름, editable 플래그를 Flutter 위젯으로 편집하도록 연결했다.
- command serialization, document convenience, widget ribbon, Rust facade smoke test를 보강했다.

## 이 작업을 진행한 이유

이전 작업에서 필드 목록과 값 수정은 가능해졌지만, upstream 웹 에디터가 제공하는 누름틀 편집 경험에는 커서 위치의 필드 감지, 필드 속성 수정, 필드 마커 제거가 포함된다. Flutter-native editor가 WebView fallback을 대체하려면 단순 값 입력뿐 아니라 커서 기반 문서 구조 편집도 Rust core API로 직접 처리해야 한다.

현재 vendored rhwp에는 본문 필드 삽입 API가 명확히 노출되어 있지 않고 머리말/꼬리말 삽입 API만 확인된다. 그래서 이번 단위는 이미 안정적으로 확인되는 커서 위치 조회, 속성 수정, 제거 API를 먼저 연결했다.

## 이 작업을 통해 배울점

- Flutter-native editor parity는 UI 복제보다 Rust core 기능을 하나씩 안전하게 노출하는 방식이 현실적이다.
- 필드/누름틀처럼 문서 구조와 렌더링이 연결된 기능은 body 문단과 table cell 문단 API를 같이 설계해야 이후 표 안 필드 편집까지 확장하기 쉽다.
- 커서 기반 구조 편집은 실패 가능성이 높으므로 `{"ok":false}` 응답을 명시적으로 에러 처리하고, editor undo snapshot 안에서 실행해야 한다.
- upstream에 본문 필드 삽입 API가 추가되면 같은 command envelope 패턴으로 Flutter-native input ribbon에 확장할 수 있다.
