# 2026-06-02 native editor open action focus

## 작업한 내용

Flutter-native editor의 파일 리본 Open 버튼을 focused editor action 경로로 연결했다.
이제 Open 버튼을 누른 뒤 editor surface를 다시 클릭하지 않아도 Ctrl/Cmd+O 같은 후속 editor
shortcut이 바로 처리된다.

기존 `onOpenRequested` callback 자체는 그대로 유지했다. 변경한 부분은 toolbar entry point가
다른 서식/삽입 버튼처럼 editor focus를 먼저 복원한 뒤 동일 callback을 호출하도록 만든 것이다.

## 이 작업을 진행한 이유

upstream web editor는 파일 열기와 단축키가 같은 editor surface 안에서 이어진다. Flutter-native
editor도 WebView 없이 실제 편집 UI가 되려면, toolbar 버튼을 누른 뒤 focus가 route나 버튼에
남아서 다음 키보드 조작이 끊기면 안 된다.

직전 작업에서 Ctrl/Cmd+O shortcut path는 테스트로 고정했지만, Open 버튼 뒤에는 다시 페이지를
클릭해야 단축키가 이어지는 빈틈이 있었다. 이번 작업은 그 우회 동작을 없앴다.

## 이 작업을 통해 배울점

Flutter toolbar 버튼은 클릭 과정에서 editor focus를 잃기 쉽다. 문서 편집기에서는 버튼 동작이
끝난 뒤 사용자가 다시 본문을 클릭하지 않아도 키보드 조작을 이어갈 수 있어야 하므로, toolbar
entry point마다 focus 정책을 명확히 해야 한다.

또한 file picker 자체는 앱 callback으로 남겨두는 것이 맞지만, editor widget은 callback 호출 전
focus 상태를 정리해 shortcut/event 흐름이 끊기지 않게 해야 한다.

## 검증

다음 widget test를 갱신해 Open 버튼 직후 page를 다시 클릭하지 않아도 Ctrl/Cmd+O가 같은
`onOpenRequested` callback으로 이어지는지 확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon requests app new and open"
```
