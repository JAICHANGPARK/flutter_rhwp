# 2026-06-02 native editor targeted text refresh

## 작업한 내용

- `RhwpViewer`에 `renderPages` 옵션을 추가해서 특정 render revision이 일부 page index에만 적용될 수 있게 했다.
- Flutter-native editor의 deferred text refresh가 pending text/delete overlay가 있는 페이지만 새 SVG로 다시 렌더하도록 변경했다.
- 기존 global refresh 경로는 유지해서 문서 교체, undo/redo, 일반 edit command처럼 재배치 영향이 큰 작업은 여전히 mounted page 전체를 갱신한다.
- viewer 단위 테스트와 native editor 텍스트 입력 테스트를 추가해 선택 페이지만 렌더되는지 검증했다.

## 이 작업을 진행한 이유

204페이지 같은 큰 HWP 문서에서 텍스트 입력 후 deferred refresh가 풀릴 때 모든 mounted page가 함께 새 SVG를 요청하면, 사용자는 입력마다 문서가 크게 refresh되는 것처럼 느낄 수 있다.

텍스트 입력은 이미 optimistic overlay로 즉시 표시하고 있으므로, 실제 SVG 동기화는 입력이 있었던 페이지부터 좁게 처리하는 편이 Flutter-native editor의 체감 안정성과 성능에 맞다.

## 이 작업을 통해 배울점

- 입력 중 refresh를 지연하는 것과 refresh 범위를 줄이는 것은 별개의 문제다.
- `renderRevision`은 전체 갱신 신호로만 쓰면 단순하지만, 큰 문서에서는 dirty page 정보를 같이 전달해야 불필요한 렌더링을 피할 수 있다.
- 텍스트 입력처럼 페이지 국소성이 높은 작업과 문단/객체/undo처럼 reflow 가능성이 있는 작업은 refresh 전략을 분리해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer can refresh only selected pages"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor refreshes only edited page after text input"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor waits for text input action before refresh"`
- `flutter analyze`
- `git diff --check`
