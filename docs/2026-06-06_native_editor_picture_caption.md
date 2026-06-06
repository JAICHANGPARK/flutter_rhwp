# Native editor picture caption

## 작업한 내용

- `RhwpObjectProperties`에 그림 캡션 속성 파싱을 추가했다.
- `RhwpCommand.setObjectProperties`와 `RhwpDocument.setObjectProperties(...)`가 `hasCaption`, `captionDirection`, `captionVerticalAlign`, `captionWidth`, `captionSpacing`, `captionIncludeMargin`을 전달하도록 확장했다.
- `RhwpNativeEditor`의 개체 속성 dialog에서 caption 지원 JSON이 있는 picture 객체에만 캡션 섹션을 표시한다.
- picture 객체에서 캡션을 켜면 rhwp core의 picture property API로 캡션 생성/설정 payload가 전달되도록 위젯 테스트를 추가했다.
- picture 객체에서 캡션을 끄면 `hasCaption:false`가 전달되고, vendored rhwp core가 기존 그림 캡션을 제거하도록 패치했다.
- `README.md`, `CHANGELOG.md`, `docs/API_SPEC.md`, `docs/NATIVE_EDITOR_PARITY.md`, `docs/TODO.md`에 이번 범위와 남은 제약을 반영했다.

## 이 작업을 진행한 이유

Flutter-native editor가 upstream Web editor를 대체하려면 단순 텍스트 편집만으로는 부족하다. 공공문서와 보고서에서는 표, 그림, 캡션이 자주 함께 쓰이므로 selected object properties에서 그림 캡션을 만들고 조정할 수 있어야 한다.

rhwp core에는 이미 picture caption 생성/설정 경로가 있으므로, 이번 작업은 새 변환기를 만들기보다 Dart API와 Flutter dialog를 연결하는 좁은 단위로 진행했다.

## 이 작업을 통해 배울점

- object property API는 shape와 picture가 같은 command envelope를 공유하지만, caption은 picture type에서만 실제 적용된다.
- Flutter UI는 core가 반환한 JSON에 caption 필드가 있을 때만 caption control을 보여줘야 shape 편집 흐름을 불필요하게 흔들지 않는다.
- 그림 캡션 생성, 설정, 삭제는 가능하지만 shape/textbox caption은 아직 별도 검증/구현이 필요하다.
- `flutter_rust_bridge_codegen` 2.12.0은 현재 generated 파일과 버전이 일치하지만, sandbox 안에서 codegen이 내부 `flutter --version` probe를 실행할 때 Flutter SDK cache 쓰기 권한에 막힐 수 있다.

## 검증

```sh
dart analyze
flutter test test/flutter_rhwp_test.dart --plain-name "object control commands serialize to Rust envelopes"
flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor object properties can create picture captions"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor object properties can remove picture captions"
cargo check --manifest-path rust/Cargo.toml
```
