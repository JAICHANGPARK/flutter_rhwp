# Native Editor Paragraph Alignment

## 작업한 내용

- `RhwpCommand.applyParaFormat`와 `RhwpCommand.applyParaFormatRange`를 Dart command surface에 추가했다.
- `RhwpDocument.applyParaFormat()`와 `RhwpDocument.applyParaFormatRange()` convenience API를 추가했다.
- Rust facade가 `applyParaFormat`과 `applyParaFormatRange` command를 받아 vendored rhwp core로 전달하도록 했다.
- vendored rhwp에 `apply_para_format_range_native` helper를 추가해 같은 section 안의 여러 문단에 문단 서식을 적용할 수 있게 했다.
- `RhwpNativeEditor` toolbar에 left, center, right, justify 정렬 버튼을 추가하고 현재 selection paragraph range에 적용하도록 연결했다.
- Dart unit test, Flutter widget test, Rust facade test를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor를 100% Flutter 위젯 기반 편집기로 키우려면 글자 입력과 선택뿐 아니라 문단 단위 편집 command도 필요하다.
문단 정렬은 HWP 편집기에서 가장 기본적인 paragraph formatting 기능이므로 toolbar에서 바로 동작해야 한다.
문서 모델의 실제 서식 적용은 Rust/rhwp core가 source of truth로 유지하고, Flutter는 selection과 command intent만 전달하는 구조를 유지했다.

## 이 작업을 통해 배울점

- 글자 서식과 달리 문단 정렬은 offset이 아니라 paragraph range가 핵심이다.
- Flutter-native editor는 UI state와 selection range를 관리하고, 문서 변경은 command envelope로 Rust에 위임하는 편이 일관된다.
- 처음에는 `apply_para_format_native`를 반복 호출하는 단순한 range helper가 유지보수에 유리하다. 성능이 문제가 되면 Rust core 내부에서 batch 적용으로 최적화할 수 있다.
- same-section body paragraph 정렬은 이번 command로 처리할 수 있지만, 표 셀, header/footer, footnote context는 별도 command context가 필요하다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `cargo fmt`
- `flutter test --plain-name "apply para format command serializes"`
- `flutter test --plain-name "apply para format range command serializes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies paragraph alignment"`
- `cargo test applies_commands_exports_and_reopens`
- `flutter test`
- `cargo test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
