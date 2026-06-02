# Native editor dirty state

## 작업한 내용

- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`에 `onDirtyChanged` callback을 추가했다.
- Rust-backed edit command, undo, redo가 성공하면 dirty 상태를 `true`로 알리도록 했다.
- HWP/HWPX 저장 export callback이 성공하면 dirty 상태를 `false`로 알리도록 했다.
- host app이 새 문서/open 등으로 `document` 인스턴스를 교체하면 dirty 상태를 `false`로 알리도록 했다.
- PDF, DOCX, text, Markdown, SVG export와 Print는 문서 저장이 아니므로 clean 처리하지 않도록 분리했다.
- example app 상태바에 dirty 표시를 붙여 수정된 문서의 파일명 뒤에 `*`가 보이도록 했다.
- widget test로 편집 후 dirty=true, PDF export 후 dirty 유지, HWP 저장 후 dirty=false 흐름을 검증했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView fallback 없이 실제 문서 편집 surface가 되려면 파일 열기, 새 문서, 닫기 전에 host app이 저장/폐기 확인을 띄울 수 있어야 한다. 이를 위해 editor 내부 edit command 결과를 앱으로 전달하는 dirty-state 경계가 필요했다.

dirty 상태는 Rust 문서 command 성공 여부와 앱의 저장 UX 사이에 걸쳐 있다. 그래서 editor가 edit command와 HWP/HWPX save export 완료 시점을 추적하고, 실제 저장 위치 선택이나 discard prompt는 host app이 결정하도록 callback만 제공했다.

## 이 작업을 통해 배울점

- `onChanged`는 문서 내용 변경 알림이고, `onDirtyChanged`는 저장/폐기 UX를 위한 상태 알림이라 역할을 나누는 편이 안전하다.
- PDF/DOCX/Text/SVG export는 문서를 저장한 것이 아니므로 dirty 상태를 지우면 사용자가 변경 사항을 잃을 수 있다.
- Close/New/Open 같은 파일 생명주기 callback을 만들 때는 dirty-state callback과 함께 설계해야 host app이 문서 폐기 확인을 구현할 수 있다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reports dirty state for edits and saves"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reports clean state when document is replaced"
```
