# Native Editor Style Picker Shortcut

## 작업한 내용

- Flutter-native editor에서 `F6`을 누르면 스타일 선택 다이얼로그가 열리도록 키보드 처리를 추가했다.
- 기존 서식 리본의 스타일 선택 기능과 동일하게 `RhwpDocument.styleList()`를 호출하고, 선택된 스타일은 기존 적용 경로를 그대로 사용한다.
- `RhwpNativeEditor opens style picker with F6 shortcut` 위젯 테스트를 추가해 단축키가 스타일 목록을 요청하고 다이얼로그를 여는지 검증했다.
- README와 CHANGELOG에 `F6` 스타일 선택 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

upstream rhwp 웹 에디터는 스타일 명령을 키보드로 바로 열 수 있는 흐름을 제공한다. Flutter-native editor도 WebView/full editor에 의존하지 않고 같은 편집 진입 경로를 제공해야 실제 문서 편집 도구처럼 사용할 수 있다.

## 이 작업을 통해 배울점

- 기존 명령 다이얼로그가 있으면 새 Rust API를 만들지 않고 키보드 진입점만 추가해도 기능 완성도가 올라간다.
- 단축키 테스트는 실제 편집까지 검증하기보다, 다이얼로그 오픈과 필요한 bridge command 호출을 분리해서 확인하면 실패 범위가 작아진다.
- Flutter-native 포팅은 큰 화면을 한 번에 복제하는 것보다 upstream의 메뉴/단축키 단위를 작은 커밋으로 맞춰가는 방식이 추적과 회귀 방지에 유리하다.
