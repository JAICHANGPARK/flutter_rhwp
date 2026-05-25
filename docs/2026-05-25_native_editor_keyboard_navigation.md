# Native Editor Keyboard Navigation

## 작업한 내용

- `RhwpNativeEditor` viewport에 전용 `FocusNode`를 추가해 문서 영역이 키보드 이벤트를 받을 수 있게 했다.
- 문서 page overlay를 누르면 native editor viewport가 focus를 얻도록 연결했다.
- `ArrowLeft`, `ArrowRight`, `Home` 키로 caret offset을 이동하도록 했다.
- `Shift + ArrowLeft/ArrowRight`로 `RhwpSelectionRange`를 확장하도록 했다.
- `Backspace`, `Delete` 키가 Rust command API의 delete flow를 호출하도록 했다.
- 선택 영역이 같은 section/paragraph 안에 있을 때 backspace/delete나 text insert 전에 selection을 먼저 삭제하도록 했다.
- widget test로 focus 획득, keyboard caret 이동, shift selection, selection delete command를 검증했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView 대체가 되려면 toolbar 입력만으로 편집 위치를 지정하는 수준을 넘어야 한다.
문서 viewport가 focus를 받고, 키보드로 caret과 selection을 움직이고, 삭제 명령을 실행할 수 있어야 실제 편집기 UX의
기본 골격이 된다.

이 작업은 IME 입력을 바로 완성하는 단계는 아니지만, IME와 shortcut을 붙일 기준 focus/selection 모델을 먼저 만든 것이다.

## 이 작업을 통해 배울점

- Flutter에서 문서 viewport와 toolbar TextField는 focus 영역을 분리해야 한다. 그렇지 않으면 toolbar 텍스트 편집과 문서 caret 이동이 충돌한다.
- selection 삭제는 command API를 직접 호출하기 전에 document source range로 정규화해야 한다.
- 현재는 같은 paragraph 안의 selection 삭제만 처리한다. multi-paragraph selection edit은 Rust command API와 문단 모델 확장이 필요하다.
- 다음 단계의 IME 구현은 이 focus 계층 위에 `TextInputClient` 또는 숨겨진 `EditableText` 기반 commit pipeline을 얹는 방식이 적합하다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test --plain-name "RhwpNativeEditor handles keyboard navigation and delete"`
- `flutter test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
