# 2026-06-02 native editor stale search results

## 작업한 내용

- Flutter-native editor의 `_runSearch`가 검색 시작 시점 query와 완료 시점 query를 비교해 stale result와 stale error를 버리도록 했다.
- fake rhwp session에 page layer tree 응답을 지연시키는 test hook을 추가했다.
- Find 실행 중 검색어를 지운 뒤 늦게 도착한 이전 layer tree 결과가 search count/highlight를 되살리지 않는 widget test를 추가했다.
- Find 실행 중 검색어를 지운 뒤 늦게 도착한 이전 layer tree error가 toolbar error state를 만들지 않는 widget test를 추가했다.
- `CHANGELOG.md`에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

Flutter-native editor는 page layer tree를 비동기로 읽어 검색 결과를 만든다. 사용자가 검색 중에 검색어를 바꾸거나 지우면 이전 query 결과나 오류가 늦게 도착할 수 있고, 이것이 현재 UI 상태를 덮으면 WebView fallback 없이 쓰는 native editor에서 검색 highlight나 toolbar error가 실제 입력값과 어긋난다.

## 이 작업을 통해 배울점

- layer-tree 기반 검색은 비동기 작업이므로 query snapshot을 잡고 완료 시점에 현재 입력값과 비교해야 한다.
- stale async failure도 stale async success와 같은 방식으로 버려야 현재 검색 UI를 오염시키지 않는다.
- 편집 후 search refresh뿐 아니라 사용자가 직접 실행한 Find도 stale result 방어가 필요하다.
- 테스트에서 fake session의 page layer tree 응답을 지연시키면 Rust bridge 호출 지연과 유사한 race를 재현할 수 있다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor ignores stale search results"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor ignores stale search errors"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
