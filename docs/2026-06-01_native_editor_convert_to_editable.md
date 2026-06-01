# Flutter-native editor convertToEditable

## 작업한 내용

- rhwp core의 `convert_to_editable_native` API를 `convertToEditable` command envelope로 Flutter Rust bridge facade에 노출했다.
- Dart `RhwpCommand.convertToEditable()`와 `RhwpDocument.convertToEditable()` convenience API를 추가했다.
- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`에 `convertToEditableOnLoad` 옵션을 추가하고 기본값을 `true`로 두었다.
- Flutter-native editor가 문서를 처음 로드할 때 upstream Web editor처럼 배포용/읽기전용 문서를 편집 가능한 상태로 변환하도록 했다.
- README, CHANGELOG, widget/unit test를 갱신했다.

## 이 작업을 진행한 이유

upstream rhwp Web editor는 파일 로드 흐름에서 `convertToEditable`을 호출한다. Flutter-native editor가 같은 문서를 열었을 때 수정이 되지 않거나 읽기전용 배포 문서처럼 동작하면, Web editor와 Native editor 사이의 사용성이 달라진다. Flutter-native editor를 100% Flutter 위젯 기반 편집기로 키우려면 로드 단계의 문서 정규화도 Rust command surface에 포함되어야 한다.

## 이 작업을 통해 배울점

- Web editor 포팅은 화면 요소만 옮기는 것이 아니라, 파일 로드 직후 실행되는 문서 상태 변환 흐름까지 맞춰야 한다.
- 내부 초기화 command는 사용자 편집 command와 분리해 테스트해야 기존 toolbar/keyboard command 검증이 안정적으로 유지된다.
- 기본값은 upstream 동작과 맞추되, 원본 배포/읽기전용 상태를 보존해야 하는 앱을 위해 escape hatch 옵션을 남기는 편이 안전하다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor converts documents to editable on load"`
- `cargo check --manifest-path rust/Cargo.toml`
