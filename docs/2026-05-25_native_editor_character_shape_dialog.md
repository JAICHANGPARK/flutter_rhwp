# Native Editor Character Shape Dialog

## 작업한 내용

- Dart command surface의 `applyCharFormat`과 `applyCharFormatRange`에 다음 속성을 추가했다.
  - `strikethrough`
  - `fontSize`
  - `textColor`
- `RhwpDocument.applyCharFormat()`와 `RhwpDocument.applyCharFormatRange()` convenience API도 같은 속성을 받을 수 있게 했다.
- `RhwpNativeEditor`의 `서식` ribbon에 `Strikethrough`와 `Character shape` 버튼을 추가했다.
- Flutter-native `글자 모양` dialog를 추가했다.
  - font size는 pt 단위로 입력받아 rhwp core가 쓰는 HWP base size 단위로 변환한다.
  - bold, italic, underline, strike toggle을 제공한다.
  - black/red/blue/green text color swatch를 제공한다.
- context menu에도 `취소선`과 `글자 모양` 항목을 추가했다.
- widget test로 dialog 입력값이 `applyCharFormatRange` command envelope에 반영되는지 검증했다.

## 이 작업을 진행한 이유

upstream web editor에는 `char_shape_dialog.js`처럼 글자 모양을 별도 dialog에서 조정하는 UI가 있다. Flutter-native editor도 toolbar 버튼만으로는 실제 HWP 편집기 경험에 부족하므로, 서식 기능을 dialog 기반으로 확장할 필요가 있다.

vendored rhwp core의 `parse_char_shape_mods`는 이미 `fontSize`, `textColor`, `strikethrough` 같은 속성을 JSON으로 받을 수 있다. 따라서 이번 작업은 Rust core를 새로 패치하기보다, Dart command envelope와 Flutter dialog를 그 계약에 맞춰 확장했다.

## 이 작업을 통해 배울점

- Flutter-native editor의 dialog는 Web DOM dialog를 옮기는 것이 아니라, Rust command JSON 계약을 기준으로 새 UI를 구성하는 편이 유지보수에 맞다.
- font size처럼 사용자 단위와 core 단위가 다른 값은 Flutter 쪽에서 명확히 변환해야 한다. 여기서는 pt 값을 HWP base size 단위인 `pt * 100`으로 변환했다.
- 색상은 문자열 CSS hex를 그대로 command properties에 넣으면 vendored rhwp core의 `json_color` 파서가 BGR 값으로 변환한다.

## 검증

- `dart format lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `flutter test test/flutter_rhwp_test.dart --plain-name "apply char format command serializes to the Rust command envelope"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "apply char format range command serializes to the Rust command envelope"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies character shape dialog values"`
- `flutter test test/rhwp_widget_test.dart`
- `flutter test`
- `flutter analyze`
- `(cd rust && cargo fmt --check)`
- `(cd rust && cargo test)`
- `(cd example && flutter test)`
- `git diff --check`
