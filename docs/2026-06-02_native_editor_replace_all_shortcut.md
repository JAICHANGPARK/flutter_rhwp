# 2026-06-02 native editor replace all shortcut

## 작업한 내용

Flutter-native editor의 replace field에서 Ctrl/Cmd+Enter를 누르면 Replace all을 실행하도록 추가했다.

기존 Replace all은 도구 리본 버튼으로만 실행할 수 있었다. 이제 replace field에 focus가 있는 상태에서
replacement 값을 입력한 뒤 Ctrl/Cmd+Enter를 누르면 같은 `onReplaceAll` callback과 undo-aware
command path를 사용해 전체 match를 교체한다.

## 이 작업을 진행한 이유

Flutter-native editor를 WebView fallback 없이 실제 편집 UI로 키우려면, 검색/바꾸기 입력면에서
마우스 버튼 없이도 주요 작업을 끝낼 수 있어야 한다. 일반 Enter는 active match 하나를 바꾸고,
Ctrl/Cmd+Enter는 전체 match를 바꾸도록 분리하면 replace field 안에서 두 작업을 모두 처리할 수 있다.

이번 작업은 새로운 변환 로직을 만들지 않고, 기존 tools-ribbon Replace all 버튼과 같은 callback을
호출한다. 그래서 Rust command bridge, undo snapshot, match 정리 동작은 기존 버튼 경로와 동일하다.

## 이 작업을 통해 배울점

보조 입력창의 keyboard shortcut은 별도 구현보다 기존 toolbar action으로 연결하는 편이 안전하다.
그래야 버튼, 키보드, 테스트가 같은 문서 편집 command path를 공유하고, Flutter-native editor가
WebView editor와 별개로 일관된 입력 레이어를 갖게 된다.

또한 일반 Enter와 Ctrl/Cmd+Enter가 모두 TextField submit 이벤트를 만들 수 있으므로, hardware key
처리와 `onSubmitted` 중복 실행을 계속 막아야 한다.

## 검증

replace field에 replacement를 입력한 뒤 Ctrl+Enter로 전체 match를 교체하는 widget test를 갱신했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor replaces all search matches"
```
