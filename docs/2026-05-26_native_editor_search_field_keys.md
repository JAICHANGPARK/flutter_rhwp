# 2026-05-26 native editor search field keys

## 작업한 내용

- Flutter-native editor tools ribbon의 검색 입력창에 upstream-style 키 처리를 추가했다.
- 검색창에서 `Enter` 또는 numpad `Enter`를 누르면 검색 결과가 없을 때는 검색을 실행하고, 결과가 있으면 다음 match로 이동한다.
- 검색창에서 `Shift+Enter`를 누르면 이전 match로 이동한다.
- 검색창에서 `Esc`를 누르면 검색어와 active match를 지우고 검색창 focus를 해제한다.
- 검색 입력창 키 흐름으로 검색 실행, 다음/이전 match 이동, 검색 해제를 검증하는 위젯 테스트를 추가했다.
- README와 CHANGELOG에 tools ribbon 검색 키 동작을 반영했다.

## 이 작업을 진행한 이유

upstream `rhwp/web/editor.js`는 검색 입력창 자체에서 `Enter`, `Shift+Enter`, `Escape`를 처리한다. Flutter-native editor에는 F3/Shift+F3 검색 이동은 있었지만, 검색창 안에서 바로 다음/이전 결과로 이동하는 흐름은 부족했다.

WebView fallback을 줄이고 Flutter 위젯 editor를 실제 편집기로 키우려면 toolbar의 버튼뿐 아니라 입력 필드의 키보드 동작도 upstream과 같은 방향으로 맞춰야 한다.

## 이 작업을 통해 배울 점

- editor toolbar의 TextField도 문서 viewport와 같은 단축키 정책의 일부다.
- 검색 실행과 검색 결과 navigation은 별도 버튼이 있어도 입력창 키 처리로 이어져야 keyboard 중심 workflow가 자연스럽다.
- Flutter에서는 TextField 주변에 `Focus.onKeyEvent`를 두어 field-local shortcut을 구현할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor cycles search matches from search field keys"`
- `flutter analyze`
