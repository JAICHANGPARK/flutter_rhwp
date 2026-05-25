# 2026-05-26 Native Editor Scoped Input Preview

## 작업한 내용

- Flutter-native editor에서 입력 중인 텍스트 미리보기 상태를 `ValueNotifier`로 분리했다.
- 스페이스나 일반 텍스트 입력으로 pending caret/text overlay가 바뀔 때 루트 editor와 `RhwpViewer` 전체가 다시 빌드되지 않도록 했다.
- 입력 커밋 후 caret 위치만 이동하는 경우에는 controller listener의 루트 `setState`를 억제하고, overlay notifier가 필요한 페이지만 갱신하도록 했다.
- README와 CHANGELOG에 입력 중 page refresh/flicker 완화 내용을 반영했다.

## 이 작업을 진행한 이유

예제 앱에서 스페이스나 텍스트를 입력할 때마다 페이지가 새로고침되는 것처럼 보였다. 기존 구현은 실제 SVG render를 지연하더라도 pending text overlay를 기록하면서 editor 루트 `setState`가 발생했고, 입력 후 cursor 이동도 controller listener를 통해 editor 전체 rebuild를 일으킬 수 있었다. 이 동작은 HWP 원본 페이지를 다시 렌더링하지 않는 상황에서도 사용자가 refresh처럼 느끼는 원인이 된다.

## 이 작업을 통해 배울점

- 문서 편집기처럼 큰 렌더 트리를 가진 UI에서는 입력 미리보기, selection, document render sync 상태를 같은 `setState` 경계에 두면 작은 입력도 큰 화면 갱신으로 보일 수 있다.
- 실제 문서 저장/렌더링은 Rust command 결과를 기준으로 유지하되, 입력 중 피드백은 Flutter overlay로 분리하면 체감 반응성이 좋아진다.
- `flutter_rust_bridge` 기반 문서 엔진은 page SVG render 비용이 있으므로, refresh 자체를 줄이는 것뿐 아니라 rebuild 범위를 줄이는 것도 중요하다.
