# 2026-06-02 native editor replace clear focus

## 작업한 내용

Flutter-native editor의 바꾸기 입력창에서 Escape를 눌렀을 때 replace 값을 지우고, 입력창 focus를
해제한 뒤 editor focus를 다시 복원하도록 변경했다.

기존에는 replace field가 blur되면서 text input client가 닫히는 흐름에 머물렀다. 이제는 parent
editor state의 `onClearReplace` callback을 통해 replace field 정리와 editor text input 복원을
같은 entry point에서 처리한다.

## 이 작업을 진행한 이유

upstream web editor는 검색/편집 보조 입력에서 빠져나온 뒤 문서 surface의 키보드 흐름으로 돌아가는
구조다. Flutter-native editor도 WebView fallback 없이 실제 문서 편집면이 되려면 검색, 바꾸기,
리본 버튼 같은 보조 UI를 조작한 뒤 본문 shortcut이 끊기지 않아야 한다.

검색 clear focus 복원과 같은 정책을 replace field에도 적용해, 사용자가 Escape 후 페이지를 다시
클릭하지 않고도 Ctrl/Cmd+G 같은 editor shortcut을 이어서 쓸 수 있게 했다.

## 이 작업을 통해 배울점

Toolbar 내부에서 focus node와 controller만 직접 만지면 parent editor의 text input connection
정책과 쉽게 어긋난다. 보조 입력을 닫는 동작은 parent editor state callback으로 올려서, field
정리와 editor focus 복원을 한 번에 처리하는 편이 안정적이다.

또한 replace field처럼 작은 입력창도 문서 편집기의 일부다. WebView를 제거하고 Flutter 위젯으로
에디터를 포팅하려면 각 입력 surface의 종료 시점에서 다음 키보드 흐름이 어디로 갈지 테스트로
고정해야 한다.

## 검증

replace field에서 Escape를 누른 뒤 page surface를 다시 클릭하지 않고 Ctrl/Cmd+G가 Go to page
dialog를 여는지 widget test로 확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles replace field enter and escape keys"
```
