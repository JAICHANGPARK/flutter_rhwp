# Native Editor Multi Paragraph Formatting

## 작업한 내용

- `RhwpCommand.applyCharFormatRange`와 `RhwpDocument.applyCharFormatRange()`를 Dart API에 추가했다.
- Rust facade가 `applyCharFormatRange` command를 받아 rhwp core의 multi-paragraph character formatting helper로 전달하도록 했다.
- vendored rhwp에 `apply_char_format_range_native`를 추가해 start paragraph, middle paragraphs, end paragraph 범위를 나눠 `apply_char_format_native`를 재사용하도록 했다.
- `RhwpNativeEditor`의 Bold, Italic, Underline 동작이 같은 section 안의 multi-paragraph selection에도 적용되도록 했다.
- Dart command unit test, Flutter widget test, Rust facade test를 추가했다.

## 이 작업을 진행한 이유

이전 단계의 글자 서식은 같은 paragraph selection에만 적용됐다.
문서 편집기에서는 여러 문단을 선택한 뒤 굵게, 기울임, 밑줄을 한 번에 적용하는 동작이 기본이므로 Flutter-native editor도 같은 selection range 모델을 지원해야 한다.
paragraph별 정확한 끝 offset 계산은 Rust 문서 모델 쪽에서 하는 것이 안전하므로 vendored rhwp에 최소 helper를 추가했다.

## 이 작업을 통해 배울점

- multi-paragraph formatting은 단순히 selection start/end를 한 command에 넣는 것만으로는 부족하고, 첫 문단/중간 문단/마지막 문단의 적용 범위를 다르게 계산해야 한다.
- Flutter는 selection intent만 전달하고, 실제 paragraph length와 char shape 적용은 Rust core에서 처리하는 편이 문서 모델과 일관된다.
- same-section body text는 하나의 command로 처리할 수 있지만, table cell, header/footer, footnote selection은 별도 context command가 필요하다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "apply char format range command serializes"`
- `flutter test --plain-name "RhwpNativeEditor applies character formatting"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
