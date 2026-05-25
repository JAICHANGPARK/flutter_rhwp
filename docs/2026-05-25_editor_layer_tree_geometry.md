# 2026-05-25 Editor Layer Tree Geometry

## 작업한 내용

- `RhwpLayerTree`에 `textRuns`, `caretRectFor`, `selectionRectsFor` helper를
  추가했다.
- rhwp `PageLayerTree` JSON의 `textRun` op에서 `bbox`, `source.stableSourceKey`,
  `placement.runToPage`, `clusters`를 읽어 paragraph offset을 page 좌표로 변환했다.
- `RhwpEditor`가 첫 페이지 layer tree를 비동기로 읽고, geometry가 있으면 기존
  command-target 좌표 대신 layer tree 기반 caret/selection rect를 사용하도록 했다.
- geometry parser unit test와 editor overlay widget position test를 추가했다.

## 이 작업을 진행한 이유

기존 Flutter-native editor overlay는 section/paragraph/offset 값을 고정 폭 글자와
고정 줄 높이로 환산했다. 이 방식은 편집 명령 위치를 표시하는 데는 충분하지만,
실제 HWP 레이아웃의 줄바꿈, 글꼴, 장평, 개별 text run 위치와 맞지 않는다.

rhwp core는 이미 `PageLayerTree`에 text source key와 cluster geometry를 포함하고
있다. Flutter 쪽에서 이 정보를 읽으면 caret과 selection을 실제 렌더링 좌표에 더
가깝게 붙일 수 있다. 이번 작업은 그 연결을 시작하는 단계다.

## 이 작업을 통해 배울점

- `stableSourceKey`의 `section:{n}/para:{n}/char:{n}` 값은 편집 command offset과
  rendering layer를 연결하는 핵심 식별자다.
- `clusters`와 `placement.runToPage`를 함께 사용하면 run-local 글자 offset을 page
  좌표로 변환할 수 있다.
- editor 좌표계는 아직 viewer scroll, page gap, multi-page 배치까지 고려해야 한다.
  그래서 이번 구현은 first-page text run geometry를 우선 적용하고, geometry가 없을
  때는 기존 fallback을 유지한다.
