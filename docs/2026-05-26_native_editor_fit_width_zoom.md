# 2026-05-26 Native Editor Fit Width Zoom

## 작업한 내용

- `RhwpViewerController.fitWidth()`를 추가해 Flutter-native editor에서도 명시적인 쪽 너비 맞춤 명령을 사용할 수 있게 했다.
- 보기 리본과 상태바에 `Fit width` 버튼을 추가하고, 현재 줌 상태와 동기화되도록 연결했다.
- viewer controller 단위 테스트와 native editor widget 테스트에 fit-width 동작 검증을 추가했다.
- README와 CHANGELOG에 Flutter-native editor의 fit-width 확대/축소 명령을 반영했다.

## 이 작업을 진행한 이유

upstream rhwp 웹 에디터는 확대/축소 UI에서 퍼센트 단계뿐 아니라 문서 폭에 맞추는 명령을 제공한다. Flutter-native editor가 실제 문서 편집기처럼 보이고 동작하려면 자주 쓰는 화면 맞춤 명령도 별도 UI로 노출되어야 한다.

## 이 작업을 통해 배울점

- 현재 `RhwpViewer`의 100% 배율은 viewport 폭 기준 레이아웃이므로, fit-width 명령은 같은 값이라도 reset zoom과 다른 사용자 의도를 표현한다.
- Web editor 기능을 Flutter로 옮길 때는 내부 동작이 같더라도 컨트롤러 API와 UI 명령 이름을 분리하면 이후 fit-page 같은 화면 맞춤 기능을 추가하기 쉽다.
- 상태바와 리본은 같은 컨트롤러 상태를 공유하므로 한쪽 UI만 추가하면 사용 흐름이 끊긴다.
