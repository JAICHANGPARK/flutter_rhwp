# 2026-05-26 native editor pending text overlay

## 작업한 내용

- `RhwpNativeEditor`에서 일반 텍스트 입력이 커밋되면 페이지 SVG가 다시 렌더되기 전까지 Flutter overlay로 입력 텍스트를 먼저 표시하도록 했다.
- `RhwpViewer`에 페이지 렌더 완료 콜백을 추가해, 새 SVG가 실제로 렌더된 뒤 pending text overlay를 제거한다.
- 입력 직후에는 새 글자가 보이고, refresh가 진행 중이어도 overlay가 유지되며, refresh 완료 후 overlay가 사라지는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

직전 작업에서 입력마다 페이지가 즉시 refresh되는 문제는 줄였지만, debounce 중에는 문서 데이터만 바뀌고 화면은 이전 SVG를 유지했다. 이 상태에서는 사용자가 입력한 글자가 잠시 보이지 않을 수 있다.

Flutter-native 에디터로 가려면 Rust 문서 모델 반영과 Flutter 입력 피드백을 분리해야 한다. 이번 작업은 렌더 비용이 큰 SVG 갱신을 기다리지 않고 Flutter 레이어에서 먼저 입력 결과를 보여주는 첫 단계다.

## 이 작업을 통해 배울 점

- 문서 엔진의 source of truth는 Rust에 두되, 편집 중 사용자 피드백은 Flutter overlay에서 optimistic하게 제공할 수 있다.
- 렌더 시작 시점이 아니라 렌더 완료 시점을 알아야 overlay 제거 타이밍을 안전하게 잡을 수 있다.
- WebView를 대체하는 편집기는 SVG 렌더러 위에 caret, selection, composing, pending input 같은 Flutter-native 상태 레이어를 쌓는 구조가 필요하다.

## 검증

- `RhwpNativeEditor keeps committed text visible until refresh completes` 위젯 테스트를 추가했다.
- 테스트는 텍스트 입력 직후 pending overlay가 보이고, render future가 대기 중일 때도 유지되며, 새 렌더가 완료된 뒤 사라지는지 확인한다.
