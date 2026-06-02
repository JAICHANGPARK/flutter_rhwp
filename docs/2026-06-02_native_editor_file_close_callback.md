# Native editor file close callback

## 작업한 내용

- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`에 `onCloseRequested` callback을 추가했다.
- Flutter-native file ribbon에 Close 버튼을 추가했다.
- Ctrl/Cmd+W가 native editor 안에서 app-provided close callback을 호출하도록 연결했다.
- example app에서는 close callback을 현재 native document, full editor source bytes, file name, metadata를 비우는 문서 닫기 흐름에 연결했다.
- widget test로 Close 버튼과 Ctrl/Cmd+W가 Rust edit command 없이 app callback만 호출하는지 검증했다.

## 이 작업을 진행한 이유

upstream rhwp Web editor와 데스크톱 문서 편집기는 파일 열기/새 문서뿐 아니라 현재 문서 닫기를 파일 메뉴의 기본 동작으로 제공한다. Flutter-native editor도 WebView fallback 없이 실제 앱 surface로 쓰려면 문서 생명주기를 host app이 제어할 수 있는 close entry point가 필요하다.

문서 닫기는 저장/폐기 확인, sandbox 파일 권한, 라우팅 전환 같은 앱 정책과 강하게 연결된다. 그래서 editor widget이 세션을 직접 닫기보다 `onCloseRequested`로 host app에 요청하는 구조를 유지했다.

## 이 작업을 통해 배울점

- 파일 생명주기 동작은 edit command가 아니라 app integration callback으로 분리해야 undo stack과 Rust 문서 command가 오염되지 않는다.
- Ctrl/Cmd+W는 플랫폼별로 창/탭 닫기와 충돌할 수 있으므로 editor surface 안에서는 명시적인 host callback 경계가 필요하다.
- native editor와 full editor fallback이 같은 app state를 공유하면 close 구현도 양쪽의 document/source bytes를 함께 정리해야 한다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon requests app close"
```
