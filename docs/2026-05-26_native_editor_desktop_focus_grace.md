# 2026-05-26 Native Editor Desktop Focus Grace

## 작업한 내용

- Flutter-native editor에서 데스크톱 텍스트 입력 중 focus가 짧게 빠졌다가 돌아오는 경우를 위한 grace window를 추가했다.
- macOS, Windows, Linux에서 IME/TextInput 연결이 순간적으로 닫히거나 `TextInputAction.done`이 늦게 들어와도 곧바로 page SVG refresh를 풀지 않도록 했다.
- 일시적인 focus 흔들림 뒤 editor가 다시 focus를 얻으면 pending text overlay를 유지하고, 실제로 focus가 나간 경우에만 지연 refresh를 진행한다.
- 관련 widget test를 추가해 transient desktop focus loss 중에는 `renderPageSvg`가 다시 호출되지 않는지 검증했다.

## 이 작업을 진행한 이유

예제 앱에서 스페이스나 텍스트를 입력할 때마다 화면이 refresh되는 것처럼 보일 수 있었다. 이전 작업에서 pending text overlay와 deferred refresh를 분리했지만, 데스크톱 플랫폼에서는 IME/TextInput 연결이나 focus 상태가 입력 사이에 아주 짧게 흔들릴 수 있다. 이 순간을 실제 입력 종료로 처리하면 deferred refresh가 즉시 풀려 입력마다 페이지가 다시 렌더링된다.

## 이 작업을 통해 배울점

- 데스크톱 Flutter의 `TextInputClient`는 모바일보다 focus/action/connection 이벤트가 더 자주 흔들릴 수 있으므로, 문서 편집기에서는 입력 종료 판단에 짧은 유예가 필요하다.
- Rust 문서 모델은 즉시 수정하되 화면 동기화는 안정된 입력 상태에서만 수행해야 대형 SVG 문서의 깜빡임을 줄일 수 있다.
- 테스트에서는 실제 OS IME를 완전히 재현하기 어렵지만, focus loss와 delayed action을 조합해 refresh release 조건을 회귀 테스트할 수 있다.
