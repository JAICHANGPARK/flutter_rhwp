# Native editor file print callback

## 작업한 내용

- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`에 `onPrintRequested` callback을 추가했다.
- Flutter-native file ribbon에 Print 버튼을 추가했다.
- `onPrintRequested`가 있으면 Ctrl/Cmd+P가 PDF export fallback 대신 print callback으로 PDF artifact를 넘기도록 했다.
- example app에서는 print callback을 PDF 저장/다운로드 흐름에 연결해 별도 printing dependency 없이 동작을 확인할 수 있게 했다.
- widget test로 Print 버튼과 Ctrl/Cmd+P가 `onPrintRequested`를 호출하고, edit command나 일반 export callback을 만들지 않는지 검증했다.

## 이 작업을 진행한 이유

upstream rhwp Web/extension 흐름은 Ctrl+P 인쇄를 에디터의 주요 파일 작업으로 다룬다. Flutter-native editor도 WebView fallback 없이 실제 편집 surface로 커지려면 저장/export뿐 아니라 print entry point가 필요하다.

다만 OS 프린터 호출은 Flutter 앱마다 선택하는 dependency와 플랫폼 정책이 다르다. 그래서 editor widget은 직접 프린터를 열지 않고, 인쇄 가능한 PDF artifact를 만들어 `onPrintRequested`로 host app에 넘기는 경계를 선택했다.

## 이 작업을 통해 배울점

- printing은 export와 비슷해 보이지만 app integration boundary가 다르다. `onExported`와 `onPrintRequested`를 분리하면 앱이 저장과 인쇄 UX를 각각 다르게 처리할 수 있다.
- Ctrl/Cmd+P는 print callback이 있을 때 print로 라우팅하고, 없을 때 기존 PDF export fallback을 유지하면 기존 앱을 깨지 않으면서 editor parity를 높일 수 있다.
- 파일 작업은 문서 변경 command가 아니므로 undo snapshot이나 Rust edit command가 발생하지 않는지 별도로 검증해야 한다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon prints PDF artifacts"
```
