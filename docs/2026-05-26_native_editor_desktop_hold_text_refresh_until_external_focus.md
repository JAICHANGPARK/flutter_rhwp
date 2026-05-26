# 2026-05-26 native editor desktop hold text refresh until external focus

## 작업한 내용

- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`에 `holdTextRefreshWhileFocused` 옵션을 추가했다.
- 데스크톱에서 이 옵션이 켜져 있으면 Space/text 입력 후 TextInput focus나 connection이 흔들려도 deferred page SVG refresh를 유지한다.
- 실제 외부 focus가 생기면 보류 중인 refresh를 해제해 문서 렌더링을 동기화한다.
- example 앱의 native editor에서 이 옵션을 켜고, full editor 전환 시에는 항상 최신 HWP bytes를 export하도록 바꿨다.
- 데스크톱 focus churn 중에는 refresh가 발생하지 않고 외부 focus 후에만 refresh되는 widget test를 추가했다.

## 이 작업을 진행한 이유

204쪽 HWP 같은 큰 문서에서는 Space나 일반 텍스트 입력마다 SVG page refresh가 풀리면 화면이 다시 그려지는 것처럼 보인다. 기존 로직은 입력 중 refresh를 지연했지만, macOS 데스크톱 TextInput이 focus/action/connection 이벤트를 흔들면 지연이 풀릴 수 있었다. 예제 앱은 실제 사용자가 보는 기본 검증 경로이므로, 입력 중에는 Flutter overlay로 새 텍스트와 caret을 보여주고 page render는 외부 focus 시점까지 미루는 편이 더 자연스럽다.

## 이 작업을 통해 배울 점

- 문서 편집기에서는 문서 모델 갱신, 입력 overlay, SVG page render 동기화를 분리해야 대형 문서 입력감이 안정된다.
- 데스크톱 TextInput 이벤트는 실제 focus 이동과 IME/플랫폼 churn을 구분해서 처리해야 한다.
- WebView fallback을 유지하더라도 Flutter-native editor는 자체 입력 UX를 별도로 안정화해야 한다.
