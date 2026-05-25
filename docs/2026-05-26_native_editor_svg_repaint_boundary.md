# Native Editor SVG Repaint Boundary

## 작업한 내용

- `RhwpViewer`가 렌더링된 SVG 페이지 위젯을 캐시할 때 `RepaintBoundary`로 감싸도록 변경했다.
- 네이티브 에디터 입력 overlay가 갱신되어도 SVG 페이지 본문은 별도 repaint layer로 유지되도록 했다.
- 기존 SVG 캐시 회귀 테스트에 repaint boundary 존재 검증을 추가했다.

## 이 작업을 진행한 이유

- 입력할 때마다 실제 SVG 재렌더는 이미 막았지만, Flutter overlay 갱신이 같은 paint tree 안에서 일어나면 페이지가 다시 칠해지는 것처럼 보일 수 있다.
- HWP 페이지는 SVG가 크고 복잡할 수 있으므로 caret, pending text, selection 같은 가벼운 overlay 변경과 문서 본문 repaint를 분리해야 한다.

## 이 작업을 통해 배울 점

- 위젯 rebuild 방지와 paint 분리는 별개의 문제다.
- 문서 편집기처럼 무거운 본문 위에 자주 바뀌는 overlay를 올리는 구조에서는 캐시와 `RepaintBoundary`를 함께 적용하는 편이 안정적이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer keeps SVG widget cached during overlay updates"`
