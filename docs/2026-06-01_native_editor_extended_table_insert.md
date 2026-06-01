# Native editor extended table insert

## 작업한 내용

- `RhwpCommand.createTableEx`와 `RhwpDocument.createTableEx`를 추가했다.
- Rust `apply_command` 브리지에서 rhwp core의 `create_table_ex_native`를 호출하도록 연결했다.
- Flutter-native 입력 리본의 표 만들기 그룹에 인라인 표 토글과 선택적 열 너비 입력을 추가했다.
- 인라인 표 삽입 시 `createTableEx`를 사용하고, 기본 표 삽입은 기존 `insertTable` 경로를 유지한다.
- 인라인 표 삽입 후 커서는 rhwp core가 반환하는 `logicalOffset`을 우선 사용하도록 했다.
- Dart command serialization, document convenience API, native editor widget interaction, Rust command bridge 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream web editor는 문서 코어의 확장 표 삽입 API를 통해 표를 본문 흐름 안에 배치할 수 있다. Flutter-native 에디터도 WebView 대체 경로로 성장하려면 단순 행/열 표 삽입뿐 아니라 HWP에서 자주 쓰는 `글자처럼 취급` 표 삽입을 지원해야 한다.

기본 표 삽입은 기존 경로를 유지하고, 사용자가 인라인 토글이나 열 너비를 지정했을 때만 확장 명령을 사용하게 해서 기존 동작을 흔들지 않았다.

## 이 작업을 통해 배울 점

- Flutter-native editor는 upstream JS API를 호출하는 대신 동일한 rhwp core 기능을 FRB Rust 브리지로 노출하는 구조가 맞다.
- 표 삽입처럼 단순해 보이는 기능도 HWP에서는 배치 방식과 열 너비 옵션이 문서 모델에 영향을 준다.
- 기존 명령을 바꾸지 않고 확장 명령을 별도로 추가하면 기존 테스트와 사용자 동작을 보존하면서 기능 범위를 넓힐 수 있다.
