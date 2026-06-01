# Native Editor Bookmarks

## 작업한 내용

- `RhwpCommand`와 `RhwpDocument`에 책갈피 목록 조회, 추가, 삭제, 이름 변경 API를 추가했다.
- Rust `apply_command` 브리지에서 rhwp core의 `get_bookmarks`, `add_bookmark`, `delete_bookmark`, `rename_bookmark` API를 호출하도록 연결했다.
- `RhwpNativeEditor` 입력 리본에 책갈피 버튼과 Flutter 다이얼로그를 추가했다.
- 다이얼로그에서 기존 책갈피 목록을 확인하고, 현재 커서 위치에 새 책갈피를 추가하거나 선택한 책갈피를 삭제/이름 변경할 수 있게 했다.
- Dart API 테스트, Flutter widget 테스트, Rust command smoke test를 추가했다.

## 이 작업을 진행한 이유

WebView full editor가 제공하던 입력 계열 기능을 Flutter-native editor로 옮기려면 문서 구조 조작 기능을 하나씩 Flutter UI와 Rust bridge로 노출해야 한다. 책갈피는 upstream rhwp core에 이미 구현되어 있어서 WebView/JS를 거치지 않고도 Flutter 위젯 기반 입력 리본에서 직접 지원하기 좋은 기능이다.

## 이 작업을 통해 배울 점

- upstream web editor 기능을 포팅할 때는 먼저 Rust core에 이미 있는 API를 확인하고, JS 호출 대신 FRB command bridge로 노출하는 편이 유지보수에 유리하다.
- 조회 command와 편집 command를 분리하면 다이얼로그는 열 때 기존 상태를 읽고, 실제 변경은 `_runEdit` 경로에서 snapshot과 refresh 정책을 그대로 사용할 수 있다.
- 문서 구조 기능은 작은 단위라도 공개 Dart API, Rust command bridge, Flutter UI, 테스트, 문서화를 같이 갱신해야 예제 앱과 패키지 API가 같은 방향으로 자란다.
