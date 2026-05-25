# 2026-05-25 Viewer Page Overlay Builder

## 작업한 내용

- `RhwpViewer.pageOverlayBuilder`를 추가해서 각 SVG 페이지 위에 page-local overlay를
  올릴 수 있게 했다.
- `RhwpEditor`의 caret/selection overlay를 viewer 밖의 전체 Stack에서 그리던 방식에서
  각 rendered page 내부 overlay로 옮겼다.
- editor overlay는 각 visible page가 자신의 `pageLayerTreeModel(page)`를 lazy load하고,
  geometry가 있으면 해당 페이지 좌표에 맞춰 caret/selection을 그린다.
- geometry가 없거나 아직 로딩 중이면 첫 페이지에서는 기존 command-target fallback을
  유지한다.
- viewer overlay builder test, editor layer-tree caret advance test, layer tree page size
  assertion을 추가했다.

## 이 작업을 진행한 이유

이전 구현은 layer tree 좌표를 읽더라도 overlay가 `RhwpViewer` 밖에서 전체 editor 위에
그려졌다. 그래서 실제 페이지 padding, scroll 위치, page gap, SVG content 크기와 overlay
좌표계가 분리될 수 있었다.

viewer가 page-local overlay hook을 제공하면 caret, selection, 검색 하이라이트, 주석,
검수 마커 같은 UI를 각 페이지 렌더링 결과에 직접 붙일 수 있다. 이번 변경은 editor뿐
아니라 앞으로 viewer 기반 기능을 확장할 때도 필요한 공통 훅이다.

## 이 작업을 통해 배울점

- 문서 렌더링 UI에서 overlay는 가능한 한 실제 rendered content와 같은 좌표계 안에
  있어야 scroll, padding, scaling 변화에 덜 취약하다.
- viewer는 SVG rendering만 담당하고, overlay 내용은 builder로 외부에서 주입하는 방식이
  재사용성이 높다.
- editor geometry는 한 번에 완성하기보다 page-local overlay, text run geometry, split
  paragraph handling 순서로 나누어 검증하는 편이 안전하다.
