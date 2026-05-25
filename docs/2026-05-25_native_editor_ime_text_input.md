# Native Editor IME Text Input

## 작업한 내용

- `RhwpNativeEditor` state가 Flutter `TextInputClient`를 구현하도록 했다.
- 문서 viewport가 focus를 얻으면 `TextInputConnection`을 열고 platform IME를 표시하도록 연결했다.
- IME composing range가 살아있는 동안에는 문서 command를 실행하지 않고 입력 버퍼만 유지하도록 했다.
- composing이 끝난 최종 문자열을 Rust `insertText` command로 commit하도록 했다.
- commit 후 platform text input state를 빈 값으로 되돌려 다음 composition을 받을 수 있게 했다.
- 같은 paragraph selection이 있을 때 text commit 전에 selection을 먼저 삭제하고 새 텍스트를 삽입하도록 했다.
- widget test로 Korean IME식 composing input이 중간 command 없이 최종 문자열만 insert하는 흐름을 검증했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView 에디터를 대체하려면 단순 단축키나 toolbar 입력이 아니라 OS/브라우저 IME 입력을 받아야 한다.
특히 한글 입력은 초성/중성/종성 조합 과정이 있으므로 composing 중간 상태를 곧바로 문서에 써버리면 실제 편집 UX가 깨진다.

이번 작업은 Flutter의 text input system을 native editor viewport에 직접 연결해, IME composition과 문서 command commit 사이에
명확한 경계를 만든 첫 단계다.

## 이 작업을 통해 배울점

- 키보드 이벤트와 IME text input은 별도 계층이다. `Focus.onKeyEvent`만으로는 한글 조합 입력을 안정적으로 받을 수 없다.
- `TextInputClient.updateEditingValue`에서는 composing range를 먼저 확인해야 한다.
- 문서 모델은 Rust command API가 source of truth이므로, Flutter input buffer는 commit 직후 비워야 한다.
- 현재는 finalized text commit까지만 처리한다. 다음 단계에서는 composing preview overlay, Enter/new paragraph, clipboard paste, multi-paragraph replacement를 확장해야 한다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test --plain-name "RhwpNativeEditor commits text input after IME composition"`
- `flutter test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
