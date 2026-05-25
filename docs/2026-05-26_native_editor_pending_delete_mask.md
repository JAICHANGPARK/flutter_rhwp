# 2026-05-26 native editor pending delete mask

## 작업한 내용

- `RhwpNativeEditor`의 본문 Backspace/Delete, 단어 단위 삭제, 선택 영역 삭제 경로에서 삭제 대상 범위를 기록하도록 했다.
- 페이지 SVG refresh를 debounce하는 동안 삭제된 텍스트가 기존 SVG에 남아 보이지 않도록 Flutter overlay mask를 추가했다.
- 선택 영역 위에 새 텍스트를 입력하는 replacement 흐름에서도 삭제 mask와 pending text overlay가 함께 동작하도록 연결했다.
- refresh된 페이지가 실제로 렌더 완료되면 `onPageRendered` 콜백으로 해당 페이지의 pending delete mask를 제거한다.

## 이 작업을 진행한 이유

텍스트 입력 refresh는 debounce되었지만, 삭제는 반대로 오래된 SVG에 삭제 전 글자가 남아 보일 수 있었다. 특히 사용자가 Backspace를 연속으로 누르면 데이터는 이미 rhwp 코어에 반영됐는데 화면은 refresh 전까지 이전 글자를 보여주기 때문에 편집기가 반응하지 않는 것처럼 느껴진다.

문서 모델은 즉시 수정하고 렌더 갱신만 늦추는 구조를 유지하려면, 입력은 pending text overlay로 보이고 삭제는 pending delete mask로 가리는 별도 optimistic UI가 필요하다.

## 이 작업을 통해 배울 점

- 편집기에서 debounce는 렌더 비용을 줄이지만, 사용자가 방금 수행한 입력/삭제 결과는 즉시 시각화해야 한다.
- SVG 기반 렌더러 위에 Flutter overlay를 얹으면 Rust 렌더 결과가 도착하기 전에도 caret, 입력 텍스트, 삭제 mask 같은 편집 상태를 자연스럽게 표현할 수 있다.
- refresh 완료 시점은 refresh 요청 시점이 아니라 새 SVG가 화면에 반영된 뒤로 잡아야 overlay가 너무 빨리 사라지지 않는다.

## 검증

- `RhwpNativeEditor masks deleted body text until refresh completes` 위젯 테스트를 추가했다.
- 테스트는 Backspace 직후에는 `renderPageSvg`와 `onChanged`가 호출되지 않고 pending delete mask가 표시되는지 확인한다.
- debounce 이후 새 SVG 요청이 시작되어도 mask가 유지되고, 새 SVG 렌더 완료 후 mask가 제거되는지 확인한다.
