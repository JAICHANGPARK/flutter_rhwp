# 2026-05-26 native editor composing overlay refresh

## 작업한 내용

- `RhwpNativeEditor`의 IME composing preview를 에디터 전체 `setState`가 아니라 overlay 전용 `ValueNotifier`로 갱신하도록 분리했다.
- `RhwpViewer` page overlay를 별도 `RepaintBoundary`로 감싸서 caret, selection, pending text, composing preview가 바뀌어도 SVG 본문 repaint와 분리되도록 했다.
- IME composing 중에는 Rust page SVG render가 다시 호출되지 않는 위젯 회귀 검증을 추가했다.
- README와 CHANGELOG에 native editor 입력 overlay refresh 정책을 반영했다.

## 이 작업을 진행한 이유

큰 HWP 문서에서는 실제 Rust render를 다시 호출하지 않아도, 입력 프리뷰나 caret overlay 변경이 큰 viewer 서브트리 build/paint와 같이 묶이면 사용자는 Space나 텍스트 입력마다 화면이 refresh되는 것처럼 느낄 수 있다.

입력 중에는 문서 명령은 Rust core에 즉시 반영하되, Flutter 화면은 SVG 본문과 입력 overlay를 다른 갱신 단위로 다루는 편이 안정적이다.

## 이 작업을 통해 배울 점

- IME composing 값은 문서 본문 상태가 아니라 입력 overlay 상태에 가깝다.
- widget rebuild 방지, repaint boundary, Rust render debounce는 서로 다른 문제이므로 각각 분리해서 다뤄야 한다.
- 대형 문서 편집기에서는 본문 SVG, caret/selection, pending input을 같은 paint/update 주기로 묶지 않는 구조가 중요하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor commits text input after IME composition"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer keeps SVG widget cached during overlay updates"`
