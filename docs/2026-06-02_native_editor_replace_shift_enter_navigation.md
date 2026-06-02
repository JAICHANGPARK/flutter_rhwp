# 2026-06-02 native editor replace shift enter navigation

## 작업한 내용

Flutter-native editor의 replace field에서 Shift+Enter를 누르면 이전 search match로 이동하도록 추가했다.

기존에는 replace field에서 Enter는 active match 교체, Ctrl/Cmd+Enter는 Replace all로 동작했지만,
이전 match로 돌아가는 키보드 경로는 search field에만 있었다. 이제 replace field에서도 Shift+Enter로
이전 match를 순회할 수 있고, 이동 후 replace field focus가 유지된다.

## 이 작업을 진행한 이유

검색/바꾸기 UI는 문서 편집 작업 중 반복해서 쓰는 보조 입력면이다. WebView 없이 Flutter-native
editor를 실제 편집기로 만들려면 replacement 값을 입력한 상태에서 마우스 없이 match 이동과 교체를
이어갈 수 있어야 한다.

일반 Enter, Shift+Enter, Ctrl/Cmd+Enter를 replace field 안에서 구분하면 active replace, previous
match navigation, replace all을 모두 같은 입력 흐름 안에서 처리할 수 있다.

## 이 작업을 통해 배울점

검색 match 이동은 검색 입력창 전용 기능이 아니라 검색/바꾸기 도구 전체의 상태 전환이다. 따라서
match 이동 함수는 search field뿐 아니라 replace field focus도 보존해야 한다.

또한 replace field의 Shift+Enter는 문서를 수정하지 않는 navigation 동작이어야 하므로, undo snapshot
이나 Rust edit command가 생성되지 않는지 테스트로 고정했다.

## 검증

replace field에서 Shift+Enter를 눌러 이전 match로 이동하고, replace field focus와 command history가
유지되는지 widget test로 확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles replace field enter and escape keys"
```
