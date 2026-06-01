# Flutter Native Editor HTML Clipboard

## 작업한 내용

- `RhwpCommand`/`RhwpDocument`에 rhwp core의 HTML 클립보드 API를 노출했다.
  - `exportSelectionHtml`
  - `exportSelectionInCellHtml`
  - `exportControlHtml`
  - `pasteHtml`
  - `pasteHtmlInCell`
- Rust facade의 JSON command handler에서 vendored rhwp의 native HTML export/import 함수를 호출하도록 연결했다.
- `RhwpNativeEditor`에서 같은 에디터 안의 body text와 단일 table cell copy/cut/paste는 plain text와 함께 내부 HTML 조각을 보관하고, 붙여넣기 시 `pasteHtml`/`pasteHtmlInCell`을 우선 사용하도록 했다.
- Flutter Clipboard가 플랫폼 공용 HTML MIME을 직접 지원하지 않기 때문에, OS clipboard에는 기존처럼 plain text를 쓰고 Flutter-native editor 내부에서만 HTML 조각을 추적한다.
- body HTML paste, table cell HTML paste, command serialization, document convenience API, Rust command path 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream `rhwp/web` 에디터는 단순 텍스트가 아니라 HTML fragment를 통해 서식이 포함된 선택 영역과 표/컨트롤 클립보드를 처리한다. Flutter-native editor가 WebView fallback과 동급으로 가려면, 텍스트 입력과 렌더링뿐 아니라 clipboard/import/export 경로도 rhwp core의 source of truth를 사용해야 한다.

이번 변경은 Flutter에서 임의로 HTML을 파싱하지 않고, 이미 rhwp core에 구현된 HTML export/import 기능을 FRB command surface로 끌어온다. 이 구조가 유지되면 이후 여러 셀 범위, 객체 HTML clipboard, 외부 앱 HTML paste 지원으로 확장할 때 Flutter UI는 선택 상태와 사용자 입력만 관리하고 문서 변환은 Rust core에 맡길 수 있다.

## 이 작업을 통해 배울 점

- Flutter `Clipboard`는 기본적으로 plain text 중심이라 Web editor처럼 `text/html` MIME을 그대로 다루기 어렵다.
- 그래도 같은 editor session 내부에서는 plain text와 HTML fragment를 함께 기억하는 방식으로 서식 보존 paste를 단계적으로 구현할 수 있다.
- Flutter-native editor 포팅은 DOM 코드를 그대로 옮기는 작업이 아니라, upstream의 문서 engine API를 Rust bridge로 노출하고 Flutter selection/input state와 맞물리는 작업이다.
- 표 셀은 row span/column span 때문에 `startRow == endRow` 같은 단순 조건으로 단일 셀 여부를 판단하면 안 되고, layer tree의 model cell index 기준으로 확인해야 한다.
