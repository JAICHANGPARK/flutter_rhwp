# 2026-05-26 Native Editor Transient Focus Hold

## 작업한 내용

- `holdTextRefreshWhileFocused` 상태에서 desktop text input 중 발생하는 일시적인 외부 focus 변화를 실제 편집기 이탈로 처리하지 않도록 수정했다.
- macOS/Windows/Linux IME 또는 text input connection churn이 `TextInputAction.done`과 함께 들어와도 pending text overlay를 유지하고, 페이지 SVG refresh를 즉시 풀지 않도록 했다.
- transient external focus가 생겼다가 편집기로 돌아오는 시나리오를 widget test로 추가했다.

## 이 작업을 진행한 이유

예제 앱에서 Space 또는 텍스트를 입력할 때마다 렌더링 페이지가 refresh되는 현상이 있었다. 대형 HWP 문서에서는 페이지 SVG 재렌더가 무겁기 때문에 입력 중에는 Flutter overlay에 입력 내용을 먼저 보여주고, 실제 페이지 refresh는 편집기 focus가 완전히 빠져나간 뒤 실행되어야 한다.

## 이 작업을 통해 배울점

- desktop Flutter text input은 키 입력 하나에도 focus/action/connection 이벤트가 여러 번 흔들릴 수 있다.
- 문서 렌더와 입력 overlay를 분리해도, focus churn을 실제 외부 focus로 오판하면 지연 refresh 전략이 깨진다.
- 입력 안정화 로직은 `TextInputAction.done`, connection close, primary focus 변경을 각각 보는 것보다 “사용자가 편집기를 떠났는가”를 기준으로 묶어야 한다.
