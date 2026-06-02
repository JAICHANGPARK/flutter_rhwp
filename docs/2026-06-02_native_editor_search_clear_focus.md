# 2026-06-02 native editor search clear focus

## 작업한 내용

Flutter-native editor의 도구 리본 검색 clear 동작을 editor focus 복원 경로로 연결했다.
이제 검색어를 지우거나 검색 필드에서 Escape를 누른 뒤, 페이지를 다시 클릭하지 않아도
Ctrl/Cmd+G 같은 editor shortcut이 바로 처리된다.

검색 상태를 비우는 내부 `_clearSearch`는 debounce timer와 match 상태만 정리하도록 유지하고,
toolbar entry point에서는 검색 필드를 blur한 뒤 editor text input connection을 다시 열도록 분리했다.

## 이 작업을 진행한 이유

upstream web editor는 검색 필드에서 Escape를 누르면 검색어를 지우고 입력 필드에서 빠져나오는
흐름을 갖고 있다. Flutter-native editor도 WebView fallback 없이 실제 편집면으로 쓰려면 검색,
바꾸기, 파일 리본 같은 보조 UI를 조작한 뒤 본문 키보드 흐름이 끊기면 안 된다.

검색 clear 버튼은 작은 UI 동작이지만, 편집기에서는 이후 키 입력이 검색 필드나 toolbar button에
남아 있는지가 사용성 차이를 만든다. 이번 작업은 검색 UI를 닫은 뒤 편집면이 다시 primary input
surface가 되도록 맞춘 것이다.

## 이 작업을 통해 배울점

Flutter에서 toolbar와 TextField는 focus를 적극적으로 가져간다. 문서 편집기처럼 한 화면 안에
본문 입력, 검색 입력, 리본 버튼이 섞인 경우에는 각 보조 UI의 종료 지점에서 focus 복귀 정책을
명시해야 한다.

또한 내부 상태 초기화 함수와 사용자 진입점 함수를 분리하면 debounce나 빈 검색어 처리 같은 내부
흐름은 그대로 두면서, 버튼/Escape 같은 UI 동작에만 editor focus 복원을 붙일 수 있다.

## 검증

검색 clear 직후 page surface를 다시 클릭하지 않고 Ctrl/Cmd+G가 Go to page dialog를 여는지
widget test로 확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor finds and highlights text from layer tree"
```
