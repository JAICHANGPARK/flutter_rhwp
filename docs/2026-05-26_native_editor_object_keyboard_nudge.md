# 2026-05-26 native editor object keyboard nudge

## 작업한 내용

- `RhwpNativeEditor`에서 선택된 객체가 있을 때 Arrow 키로 위치를 1 page unit씩 이동하도록 했다.
- Shift+Arrow 입력은 같은 경로에서 10 page unit씩 이동한다.
- 이동 결과는 기존 객체 속성 브리지의 `setObjectProperties` 명령으로 rhwp 코어에 반영된다.
- 선택 객체 키보드 이동을 검증하는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

객체 편집은 마우스 드래그만으로는 정밀한 위치 조정이 어렵다. 실제 문서 편집기에서는 선택한 그림, 도형, 표지 객체를 방향키로 조금씩 움직이는 흐름이 자연스럽기 때문에 Flutter-native 편집기에도 같은 기본 조작이 필요했다.

## 이 작업을 통해 배울 점

- 객체 선택 상태에서는 Arrow 키가 텍스트 caret 이동보다 객체 편집 명령으로 먼저 해석되어야 한다.
- 화면상의 선택 bounds와 rhwp 문서 속성은 같은 좌표계가 아닐 수 있으므로, 기존 bounds-to-properties 매핑을 재사용하는 것이 안전하다.
- Shift 보조키는 선택 확장뿐 아니라 객체 조작에서는 더 큰 이동 단위로 해석될 수 있다.

## 검증

- `RhwpNativeEditor nudges selected objects with keyboard` 위젯 테스트를 추가했다.
- 테스트는 Shift+ArrowRight 입력 후 선택 객체 bounds와 `setObjectProperties` 명령의 `horzOffset` 값이 함께 이동하는지 확인한다.
