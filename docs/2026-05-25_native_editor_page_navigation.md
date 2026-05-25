# 2026-05-25 native editor page navigation

## 작업한 내용

- `RhwpViewerController`에 현재 페이지 상태와 `goToPage`, `previousPage`, `nextPage` 페이지 이동 API를 추가했다.
- `RhwpViewer`가 내부 페이지 key와 vertical scroll controller를 사용해 controller의 페이지 이동 요청을 실제 스크롤로 반영하도록 연결했다.
- `RhwpNativeEditor` 보기 리본에 이전/다음 페이지 버튼과 현재 페이지 카운터를 추가했다.
- Flutter-native 검색 결과를 선택할 때 해당 결과가 있는 페이지로 이동 요청을 같이 보내도록 했다.

## 이 작업을 진행한 이유

- upstream 웹 에디터는 문서 탐색과 검색 결과 이동이 에디터 UX의 기본 흐름이다. Flutter-native 에디터도 검색 결과를 선택만 하는 수준을 넘어 해당 페이지로 이동할 수 있어야 한다.
- 페이지 이동은 검색뿐 아니라 앞으로 추가할 쪽 설정, 머리말/꼬리말, 페이지 단위 편집 기능의 기반이 된다.
- 기존 viewer는 스크롤 가능한 렌더링만 제공했고 외부 controller가 특정 페이지를 요청할 수 없었기 때문에 네이티브 에디터가 문서 탐색 상태를 제어하기 어려웠다.

## 이 작업을 통해 배울점

- Flutter-native 에디터에서 페이지 이동은 문서 command가 아니라 viewer state이므로 Rust bridge 명령과 분리해 controller 레벨에 두는 편이 맞다.
- lazy page rendering 구조에서는 이미 빌드된 페이지는 `Scrollable.ensureVisible`로 이동하고, 아직 빌드되지 않은 페이지는 스크롤 위치를 먼저 추정해 노출시킨 뒤 다시 보정하는 방식이 필요하다.
- 검색, 페이지 버튼, 향후 썸네일/목차 탐색은 모두 같은 `RhwpViewerController.goToPage` 경로를 사용해야 동작이 일관된다.

## 검증

- `RhwpViewerController.goToPage()`가 요청한 페이지를 lazy viewer에서 렌더링 범위로 가져오는 widget test를 추가했다.
- `RhwpNativeEditor` 검색 결과가 다른 페이지에 있을 때 해당 페이지로 이동하고, 검색 하이라이트를 표시하는 기존 검색 test를 확장했다.
