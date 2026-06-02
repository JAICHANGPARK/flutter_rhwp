# 2026-06-02 native editor file open shortcut

## 작업한 내용

Flutter-native editor에서 Ctrl/Cmd+O 파일 열기 단축키가 파일 리본의 Open 버튼과 같은
`onOpenRequested` callback을 호출하는지 widget test로 고정했다.

기존 구현은 key handler에 이미 연결되어 있었지만, 테스트는 버튼 경로만 검증하고 있었다.
이번 작업으로 앱이 file picker를 `onOpenRequested`에 연결했을 때 버튼과 단축키가 같은 경계로
동작한다는 점을 명시했다.

## 이 작업을 진행한 이유

upstream web editor는 파일 입력을 에디터의 기본 작업으로 다루고, 키보드 조작과 toolbar 조작을
같은 문서 열기 흐름으로 연결한다. Flutter-native editor도 WebView 없이 실제 editor surface가
되려면 file picker 연결점이 버튼에만 묶이지 않고 키보드 shortcut에서도 동일하게 호출되어야 한다.

이 기능은 플러그인 내부에서 직접 파일 시스템을 여는 것이 아니라 앱이 제공한 callback을 호출하는
구조를 유지한다. 그래서 Android/iOS sandbox, desktop file picker, Web upload 같은 플랫폼별
처리는 example/app 쪽에 남기고, editor widget은 명령 경계만 안정적으로 제공한다.

## 이 작업을 통해 배울점

Flutter-native editor의 파일 작업은 Rust core command가 아니라 앱 통합 callback이다. 따라서
테스트도 파일 시스템 접근 여부가 아니라 callback 호출 여부와 Rust command가 불필요하게 나가지
않는지를 검증해야 한다.

또한 WebView editor를 Flutter 위젯으로 옮길 때는 UI 버튼만 만드는 것으로 끝나지 않는다. 같은
작업이 shortcut, status, context menu 등 여러 entry point에서 같은 command/callback 경계를
공유해야 유지보수가 쉽다.

## 검증

다음 widget test를 보강해 파일 리본 Open 버튼과 Ctrl/Cmd+O 단축키가 같은 callback을 호출하는지
확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon requests app file open"
```
