# 2026-06-02 native editor status go to page

## 작업한 내용

- Flutter-native editor 상태바의 현재 페이지 표시를 클릭하면 `Go to page` 다이얼로그가 열리도록 연결했다.
- 상태바 페이지 이동도 보기 리본과 Ctrl/Cmd+G 단축키가 쓰는 기존 `_showGoToPageDialog` 경로를 재사용한다.
- 문서가 로딩 중이거나 page count를 모를 때는 상태바 페이지 표시 클릭을 비활성화한다.
- widget test로 보기 리본, 단축키, 상태바 클릭이 모두 같은 페이지 이동 흐름을 사용하는지 검증했다.

## 이 작업을 진행한 이유

WebView fallback 없이 Flutter 위젯 에디터를 실제 편집기로 키우려면 status bar도 현재 상태 표시뿐 아니라 문서 탐색을 바로 실행하는 editor chrome이어야 한다. 페이지 표시는 사용자가 가장 자연스럽게 클릭할 수 있는 탐색 지점이므로, 기존 Go to page 기능을 상태바에 연결했다.

## 이 작업을 통해 배울점

- 같은 기능은 ribbon, shortcut, status bar가 각각 별도 구현을 갖기보다 하나의 dialog/action 경로를 공유해야 한다.
- status bar의 표시 텍스트를 조작 가능한 위젯으로 바꾸더라도 기존 key를 Text에 유지하면 테스트와 접근 경로를 안정적으로 보존할 수 있다.
- 문서 metadata가 아직 준비되지 않은 상태에서는 editor chrome 액션을 비활성화해 불완전한 dialog 상태를 피해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor jumps to page from view ribbon and shortcut"`
