# 2026-05-25 Editor Multi Paragraph Selection

## 작업한 내용

- `RhwpLayerTree.selectionRectsForRange`를 추가해서 selection 시작/끝 위치가 서로
  다른 paragraph여도 page-local text run overlap을 계산하도록 했다.
- 기존 단일 paragraph용 `selectionRectsFor`는 유지하고, editor overlay는 새 range API를
  사용하도록 변경했다.
- 단위 테스트로 paragraph 0 중간부터 paragraph 1 중간까지 선택했을 때 두 개의 selection
  rect가 나오는지 검증했다.
- widget test로 `RhwpEditor`가 layer tree 기반 page overlay에서 여러 paragraph selection
  rect를 실제로 그리는지 검증했다.

## 이 작업을 진행한 이유

실제 HWP 편집에서는 selection이 한 문단 안에서만 끝나지 않는다. 이전 구현은
`start.paragraph == end.paragraph`일 때만 layer tree selection을 그렸기 때문에, 여러 문단에
걸친 선택은 geometry가 있어도 화면에 표시되지 않았다.

page-local overlay가 들어간 뒤에는 각 페이지가 자신이 가진 text run만 보고 selection range와
겹치는 부분을 그릴 수 있다. 이 방식은 selection이 여러 페이지에 걸쳐도 visible page마다
자신의 rect만 그리면 되므로 viewer virtualization과도 잘 맞는다.

## 이 작업을 통해 배울점

- selection range는 document 좌표계(section, paragraph, offset)로 정규화하고, 각 page
  layer tree는 자신의 text run과 겹치는 부분만 page 좌표계 rect로 반환하는 구조가 단순하다.
- start/end가 다른 paragraph인 경우에도 run 단위 overlap을 계산하면 split run, line wrap,
  page split을 단계적으로 처리할 수 있다.
- 아직 table cell, textbox, bidi 같은 비선형 흐름은 별도 context가 필요하지만, range API를
  먼저 만든 덕분에 그 context를 추가할 자리가 생겼다.
