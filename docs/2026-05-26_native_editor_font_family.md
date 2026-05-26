# Native editor font family

## 작업한 내용

- `RhwpCommand.applyCharFormat`, `applyCharFormatRange`, `applyCharFormatInTableCell`에 `fontFamily` 옵션을 추가했다.
- Rust facade에서 `fontFamily`를 받으면 rhwp core의 `find_or_create_font_id_native`로 font id를 찾거나 등록하고, 기존 native char-format command가 이해하는 `fontId`/`fontIds` 속성으로 변환하도록 했다.
- 글꼴 변경 시 글자 폭이 달라질 수 있으므로 vendored rhwp의 char-format reflow 조건에 font id 변경도 포함했다.
- `RhwpNativeEditor` 서식 리본에 글꼴 선택 드롭다운을 추가했다.
- 글자 모양 다이얼로그에도 글꼴 선택 필드를 추가해 upstream 웹 에디터의 기본 글꼴 선택 흐름에 맞췄다.
- Dart command 직렬화 테스트, 네이티브 에디터 위젯 테스트, Rust facade command smoke test를 갱신했다.

## 이 작업을 진행한 이유

upstream web 에디터는 글자 모양 툴바에서 글꼴을 직접 선택할 수 있다. Flutter-native 에디터는 크기, 색상, 굵게/기울임 등은 지원했지만 글꼴 선택이 빠져 있어 실제 문서 편집기 UX와 차이가 컸다. WebView fallback을 유지하더라도 100% Flutter 위젯 에디터로 가려면 글꼴 선택이 Dart UI와 Rust 문서 명령 경로를 모두 통과해야 한다.

## 이 작업을 통해 배울 점

- HWP 글꼴 적용은 문자열만 저장하는 방식이 아니라 문서 내부 font face table의 id를 참조한다.
- Flutter UI는 `fontFamily`처럼 의미 있는 값을 전달하고, Rust facade가 rhwp core의 font id 등록 API로 변환하는 구조가 유지보수에 유리하다.
- 기존 `fontId` 기반 command와 호환되도록 facade에서 `fontId`/`fontIds`를 채워 주면 Dart API는 더 자연스럽게 유지할 수 있다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
- `flutter test test/flutter_rhwp_test.dart --plain-name "apply char format command serializes to the Rust command envelope"`는 현재 샌드박스가 Flutter test의 `127.0.0.1:0` 서버 소켓 생성을 막아 실행하지 못했다.
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies inline character toolbar values"`는 현재 샌드박스가 Flutter test의 `127.0.0.1:0` 서버 소켓 생성을 막아 실행하지 못했다.
