# Flutter-native editor merge paragraph

## 작업한 내용

- rhwp core의 `merge_paragraph_native`를 `mergeParagraph` command envelope로 노출했다.
- Dart `RhwpCommand.mergeParagraph()`와 `RhwpDocument.mergeParagraph()`를 추가했다.
- 본문 문단 경계에서 Backspace/Delete를 누를 때 기존 `deleteRange` 대신 `mergeParagraph`를 호출하도록 바꿨다.
- Rust command smoke test, Dart command serialization/convenience test, widget keyboard-boundary test를 갱신했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView 없이 실제 문서 구조 편집을 담당하려면 문단 분할, 삽입, 삭제뿐 아니라 병합도 rhwp core의 전용 명령으로 처리해야 한다. 기존 구현은 문단 경계 병합을 범위 삭제로 표현했지만, upstream core에는 병합 전용 API가 있으므로 이 경로를 직접 쓰는 편이 문서 모델의 의도를 더 명확히 보존한다.

## 이 작업을 통해 배울점

- UI 입력은 Flutter에서 처리하더라도 문서 구조 변경의 source of truth는 core command에 두는 편이 안정적이다.
- 문단 병합은 삭제 range가 아니라 현재 문단을 이전 문단에 합치는 구조 명령이므로, cursor는 core가 반환하는 `paraIdx`와 `charOffset`으로 되돌리는 것이 맞다.
- 같은 키 입력이라도 Backspace at paragraph start와 Delete at paragraph end는 둘 다 같은 `mergeParagraph` 명령으로 정규화할 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor merges paragraphs at keyboard boundaries"`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter analyze`
- `git diff --check`
