# 2026-05-25 native editor text search

## 작업한 내용

- `RhwpNativeEditor`의 도구 리본에 Flutter-native 찾기 입력창, 실행, 이전/다음, 초기화 버튼을 추가했다.
- 검색은 `RhwpDocument.pageLayerTreeModel()`로 각 페이지의 text run을 읽고, 일치하는 본문 위치를 `RhwpSelectionRange`로 선택한다.
- 검색 결과는 page overlay에서 노란색 하이라이트로 표시하고, 현재 결과는 더 진한 테두리로 구분한다.
- 검색은 문서 변경 명령을 만들지 않도록 했고, widget test에서 command 없이 선택/하이라이트만 갱신되는 흐름을 검증했다.

## 이 작업을 진행한 이유

- upstream rhwp 웹 에디터는 검색 입력, 검색 결과 이동, 선택 overlay를 갖고 있다. Flutter-native 에디터가 WebView를 대체하려면 문서 탐색 기능도 Flutter 위젯으로 포팅해야 한다.
- 이미 Flutter 쪽에 page layer tree 모델과 text run geometry가 있으므로, JS 검색 코드를 부르지 않고 Rust bridge 결과만으로 검색 UI를 만들 수 있다.
- 검색 결과를 실제 문서 위치로 선택해두면 이후 검색 결과 페이지 스크롤, replace, selection 기반 서식 적용으로 확장하기 쉽다.

## 이 작업을 통해 배울점

- Flutter-native 에디터에서 문서 탐색 기능도 렌더링 결과가 아니라 source position이 있는 layer tree를 기준으로 구현해야 한다.
- 검색 결과는 편집 명령이 아니라 view/editor state이므로 Rust command history와 분리해야 한다.
- 검색 highlight와 selection overlay는 같은 page coordinate 변환을 공유해야 확대/축소와 페이지 크기 변화에서도 위치가 어긋나지 않는다.

## 검증

- `RhwpNativeEditor`에서 검색어를 입력하고 찾기를 실행하면 page layer tree text run에서 일치 항목을 찾는 widget test를 추가했다.
- 검색 결과가 `RhwpSelectionRange`로 선택되고, `rhwp-editor-search-active` overlay가 표시되며, 문서 변경 command는 발생하지 않는 것을 확인했다.
