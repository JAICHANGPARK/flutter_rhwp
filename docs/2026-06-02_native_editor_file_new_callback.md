# Native editor file new callback

## 작업한 내용

- `RhwpNativeEditor`/`RhwpEditor`/`RhwpCommandEditor`에 `onNewRequested` callback을 추가했다.
- Flutter-native file ribbon에 New 버튼을 추가하고, Ctrl/Cmd+N 단축키도 같은 callback을 호출하도록 연결했다.
- example app의 native editor가 기존 상단 New 버튼과 같은 `_createBlankDocument` 흐름을 사용하도록 연결했다.
- widget test로 file ribbon New, Ctrl/Cmd+N, Open 버튼이 Rust 문서 command를 만들지 않고 앱 callback만 호출하는지 검증했다.

## 이 작업을 진행한 이유

upstream Web editor의 파일 메뉴는 문서 열기뿐 아니라 새 문서 생성도 editor chrome 안에서 제공한다. Flutter 위젯 기반 editor도 WebView fallback 없이 실제 편집 surface로 쓰이려면 파일 작업 entry point가 native ribbon과 keyboard shortcut에 있어야 한다.

다만 새 문서 생성은 플랫폼별 저장 정책, 파일명, 앱 상태 교체 방식이 얽혀 있다. 그래서 editor widget이 직접 파일 시스템이나 앱 상태를 만지지 않고 `onNewRequested` callback으로 host app에 위임하게 했다.

## 이 작업을 통해 배울점

- Flutter-native editor의 파일 작업은 Rust command와 앱 통합 callback을 분리해야 한다.
- 같은 동작은 ribbon button과 keyboard shortcut이 같은 callback 경계를 공유해야 테스트와 유지보수가 쉬워진다.
- 예제 앱은 public API 사용법을 보여주는 역할도 하므로, 새 callback은 라이브러리 테스트뿐 아니라 example 연결까지 같이 갱신해야 한다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon requests app new and open"
```
