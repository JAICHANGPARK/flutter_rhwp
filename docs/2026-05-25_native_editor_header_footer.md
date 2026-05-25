# 2026-05-25 native editor header footer

## 작업한 내용

- Dart `RhwpCommand`에 `createHeaderFooter` command envelope을 추가했다.
- `RhwpDocument.createHeaderFooter()`, `createHeader()`, `createFooter()` 편의 API를 추가했다.
- Rust `apply_command` dispatch에 `createHeaderFooter`를 추가하고 vendored rhwp의 `create_header_footer_native()`를 호출하도록 연결했다.
- Flutter-native 에디터의 `쪽` 리본에서 Header/Footer 버튼을 활성화했다.
- Dart command serialization test, Flutter widget test, Rust command integration test를 추가/확장했다.

## 이 작업을 진행한 이유

- upstream 웹 에디터의 쪽/문서 구성 기능을 Flutter-native 리본으로 옮기려면 page ribbon이 실제 문서 command를 실행해야 한다.
- rhwp 코어에는 이미 머리말/꼬리말 생성 native API가 있으므로, JS/WebView를 호출하지 않고 FRB Rust command 경로로 노출하는 것이 맞다.
- Header/Footer는 문서 레이아웃에 영향을 주는 기능이라 단순 UI placeholder보다 실제 command, rerender, save/export 경로까지 이어지는 구현이 필요하다.

## 이 작업을 통해 배울점

- Flutter-native editor 포팅은 버튼 UI를 흉내 내는 작업이 아니라, 각 리본 action을 Rust source of truth command에 하나씩 연결하는 작업이다.
- 문서 구조 command는 `RhwpDocument` 편의 API와 `RhwpCommand` envelope을 같이 추가해야 테스트와 앱 코드가 같은 계약을 사용할 수 있다.
- 머리말/꼬리말 생성은 페이지 렌더링 결과에 영향을 주므로 편집 후 viewer key를 갱신하는 기존 `_runEdit()` 경로를 재사용하는 것이 안전하다.

## 검증

- Dart test로 `createHeaderFooter` command JSON이 `section`, `isHeader`, `applyTo` 값을 안정적으로 직렬화하는지 확인했다.
- Flutter widget test로 `RhwpNativeEditor`의 Header/Footer 버튼이 각각 `createHeaderFooter` command를 생성하고 `onChanged`를 호출하는지 확인했다.
- Rust test에서 `apply_command`가 header와 footer 생성 command를 받아 HWP/HWPX export/reopen 흐름까지 유지하는지 확인했다.
