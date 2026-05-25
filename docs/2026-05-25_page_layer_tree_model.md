# 2026-05-25 Page Layer Tree Model

## 작업한 내용

- `RhwpLayerTree`와 `RhwpLayerNode` Dart 모델을 추가했다.
- 기존 `RhwpDocument.pageLayerTree(int page)` raw JSON API는 유지하고,
  `RhwpDocument.pageLayerTreeModel(int page)` helper를 추가했다.
- layer tree JSON에서 `children`, `nodes`, `layers`, `runs`, `spans` 같은
  일반적인 중첩 배열을 순회하고, `x/y/width/height`, `left/top/right/bottom`,
  `bounds`, `bbox`, `rect`, `frame` 형태의 좌표를 `Rect`로 변환하도록 했다.
- 공개 export, README, CHANGELOG, Dart unit test를 함께 갱신했다.

## 이 작업을 진행한 이유

Flutter-native editor의 caret/selection overlay가 현재는 command target 좌표를
단순 계산해서 표시한다. 실제 문서 레이아웃에 맞춘 선택 영역을 만들려면 rhwp가
반환하는 page layer tree를 Dart에서 안정적으로 탐색할 수 있어야 한다.

이번 변경은 upstream JSON 스키마가 조금 달라져도 raw JSON을 보존하면서 공통
필드를 typed API로 읽을 수 있게 만드는 기반 작업이다. 다음 단계에서는 이 모델을
editor overlay에 연결해 실제 텍스트 node bounds 기준으로 caret과 selection을
계산할 수 있다.

## 이 작업을 통해 배울점

- Rust core가 제공하는 JSON API는 Flutter UI에서 바로 쓰기보다, raw 데이터와
  typed convenience layer를 함께 제공하는 방식이 유지보수에 유리하다.
- 문서 레이아웃 관련 API는 upstream 스키마가 바뀔 가능성이 있으므로 parser를
  엄격하게 묶기보다 공통 필드에 관대하게 대응하고 원본 JSON을 노출하는 편이
  실전 사용에 안전하다.
- editor 기능은 명령 적용, 렌더링, 좌표 매핑이 분리되어야 한다. 이번 모델은
  렌더링 결과와 편집 UI 사이의 좌표 매핑을 위한 중간 계층 역할을 한다.
