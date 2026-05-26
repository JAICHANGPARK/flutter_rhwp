# 2026-05-26 native editor live search input

## 작업한 내용

- Flutter-native editor tools ribbon 검색창에 300ms debounce live search를 추가했다.
- 검색창 입력이 비면 pending search timer와 active search highlight를 즉시 정리하도록 했다.
- 버튼/Enter 검색은 즉시 실행하고, 타이핑 중 검색만 debounce되도록 분리했다.
- 검색창 입력 후 delay 전에는 결과가 바뀌지 않고, delay 뒤 page layer tree 검색이 실행되는 위젯 테스트를 추가했다.
- README와 CHANGELOG에 live search 동작을 반영했다.

## 이 작업을 진행한 이유

upstream `rhwp/web/editor.js`는 검색 입력창의 `input` 이벤트를 300ms debounce로 받아 `performSearch`를 호출한다. Flutter-native editor도 버튼을 누르는 방식만 지원하면 기능은 가능하지만, 실제 문서 편집기의 검색 감각은 upstream과 다르다.

검색어를 입력하는 즉시 결과 후보가 갱신되되, 큰 문서에서 매 키마다 page layer tree 검색을 돌리지 않도록 debounce를 두는 방식이 Flutter-native editor의 목표와 맞다.

## 이 작업을 통해 배울 점

- editor parity는 command API뿐 아니라 toolbar field의 이벤트 타이밍까지 포함한다.
- 큰 문서에서는 live search도 즉시 실행보다 debounce가 필요하다.
- 버튼/제출 검색과 typing 기반 검색은 같은 search engine을 쓰되 scheduling만 분리하는 편이 유지보수에 좋다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor debounces live search field input"`
- `flutter analyze`
