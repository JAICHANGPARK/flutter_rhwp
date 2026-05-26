# 2026-05-26 Native Editor External Focus Refresh Grace

## 작업한 내용

- `RhwpNativeEditor`에서 desktop text input 중 외부 focus처럼 보이는 transient churn이 들어와도 바로 page SVG refresh를 풀지 않도록 external-focus release grace를 추가했다.
- `holdTextRefreshWhileFocused`가 켜져 있고 pending text overlay가 남아 있으면, 외부 focus 감지 시 잠깐 기다렸다가 실제로 editor를 떠난 상태가 유지될 때만 deferred refresh를 진행한다.
- 입력이 다시 들어오거나 editor focus가 돌아오면 external-focus release timer를 취소해 Space/text 입력 중 페이지가 다시 렌더링되지 않도록 했다.
- macOS desktop input churn을 재현하는 widget test를 추가했다.

## 이 작업을 진행한 이유

예제 앱에서 스페이스나 텍스트를 입력할 때마다 화면이 refresh되는 현상이 있었다. 문서 명령은 정상적으로 queue 처리되고 있었지만, macOS desktop text input이 입력 사이에 잠깐 외부 focus처럼 관측되면 `holdTextRefreshWhileFocused`의 보류 상태가 풀릴 수 있었다.

대형 HWP 문서는 page SVG refresh 비용이 크기 때문에 입력 중에는 Flutter overlay에 커밋된 텍스트를 먼저 보여주고, 실제 page SVG 동기화는 사용자가 editor를 떠났다고 판단될 때 실행하는 편이 맞다.

## 이 작업을 통해 배울점

- desktop Flutter text input에서는 `TextInputAction.done`, connection close, primary focus 변경이 키 입력 하나에도 연속으로 흔들릴 수 있다.
- 문서 모델 반영과 화면 렌더 동기화는 분리해야 한다. 모델은 즉시 수정하고, 무거운 SVG refresh는 입력 세션이 안정된 뒤 처리해야 한다.
- focus churn을 실제 외부 focus와 구분하려면 즉시 판단보다 짧은 grace window와 취소 조건을 함께 두는 방식이 안정적이다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor delays external focus refresh during desktop input churn"`는 현재 sandbox에서 localhost test server socket 생성 권한이 없어 실행이 차단된다.
