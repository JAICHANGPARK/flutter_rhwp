# 2026-05-25 native editor zoom controls

## 작업한 내용

- `RhwpNativeEditor`의 보기 리본에 현재 확대 비율 표시와 확대, 축소, 100% 초기화 버튼을 연결했다.
- 하단 상태바의 고정 `100%` 표시를 실제 `RhwpEditorController.zoom` 값과 동기화했다.
- 상태바에도 확대/축소 버튼을 추가해 upstream 에디터처럼 문서 하단에서 바로 배율을 조절할 수 있게 했다.
- widget test에서 리본 확대, 상태바 축소, 리본 100% 초기화가 같은 controller zoom 상태를 공유하는지 검증했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터는 WebView 에디터를 대체해야 하므로 문서 편집기에서 기본적으로 기대하는 보기 배율 조절 UX가 필요하다.
- 기존에는 `RhwpViewerController`의 zoom은 동작하지만 native editor 상태바가 항상 `100%`로 보이는 불일치가 있었다.
- 보기 리본과 상태바가 같은 controller를 바라보게 하면 향후 맞춤 배율, 페이지 맞춤, 폭 맞춤 같은 기능도 같은 경로로 확장할 수 있다.

## 이 작업을 통해 배울점

- Flutter-native 에디터의 보기 상태는 문서 변경 command와 분리되어야 하며, controller 상태만 변경하는 것이 맞다.
- 리본과 상태바처럼 서로 다른 UI surface가 같은 기능을 노출할 때는 별도 상태를 만들지 않고 공유 controller를 source of truth로 두는 편이 안정적이다.
- 확대/축소는 렌더링 SVG를 다시 만드는 기능이 아니라 viewer layout을 바꾸는 기능이므로 편집 히스토리나 저장 dirty 상태와 연결하지 않는다.

## 검증

- `RhwpNativeEditor` widget test로 리본 확대 버튼을 누르면 리본/상태바 표시가 `125%`로 같이 바뀌는 것을 확인했다.
- 상태바 축소 버튼과 리본 100% 초기화 버튼이 `RhwpEditorController.zoom`을 다시 `1.0`으로 맞추는 것을 확인했다.
