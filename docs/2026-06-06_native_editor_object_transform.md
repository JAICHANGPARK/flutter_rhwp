# Native editor object transform

## 작업한 내용

- `RhwpObjectProperties`에 `rotationAngle`, `horzFlip`, `vertFlip` 파싱을 추가했다.
- `RhwpCommand.setObjectProperties`와 `RhwpDocument.setObjectProperties(...)`가 회전/대칭 속성을 command envelope에 포함할 수 있게 확장했다.
- `RhwpNativeEditor`의 개체 속성 dialog에서 rhwp core가 회전/대칭 필드를 반환하는 객체에만 회전, 좌우 대칭, 상하 대칭 컨트롤을 표시하도록 했다.
- 선택 shape 객체의 회전/대칭 속성 변경이 `setObjectProperties` payload로 전달되는 widget test를 추가했다.
- `README.md`, `CHANGELOG.md`, `docs/API_SPEC.md`, `docs/NATIVE_EDITOR_PARITY.md`, `docs/TODO.md`에 지원 범위와 남은 검증 항목을 반영했다.

## 이 작업을 진행한 이유

upstream Web editor에는 개체 회전/대칭 기능이 있고, Flutter-native editor parity 문서에서는 해당 항목이 미구현 상태였다. vendored rhwp core는 shape/picture 속성 JSON에서 이미 `rotationAngle`, `horzFlip`, `vertFlip`을 읽고 쓰는 경로를 갖고 있으므로, Flutter 쪽 API와 dialog를 연결하면 WebView 의존도를 한 단계 줄일 수 있다.

## 이 작업을 통해 배울점

- 회전/대칭은 별도 command를 만들 필요 없이 기존 object properties command에 안전하게 얹을 수 있다.
- 모든 객체가 회전/대칭 속성을 반환한다고 가정하면 안 된다. UI는 core 응답에 해당 필드가 있을 때만 컨트롤을 보여줘야 한다.
- 이번 작업은 object properties dialog/API 경로를 여는 것이고, 전용 ribbon preset, shortcut, 실제 문서 round-trip은 별도 검증이 필요하다.

## 검증

```sh
dart analyze
flutter test test/flutter_rhwp_test.dart --plain-name "object control commands serialize to Rust envelopes"
flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor object properties can transform selected objects"
```
