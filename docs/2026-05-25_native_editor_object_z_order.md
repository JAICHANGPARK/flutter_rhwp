# 2026-05-25 native editor object z order

## 작업한 내용

- Dart command surface에 `RhwpObjectZOrderOperation`과 `changeObjectZOrder`를 추가했다.
- Rust facade가 `changeObjectZOrder`를 받아 rhwp core의 `change_shape_z_order_native`로 전달하도록 했다.
- `RhwpNativeEditor` edit ribbon에 선택 개체를 맨 앞으로, 앞으로, 뒤로, 맨 뒤로 이동하는 Flutter 버튼을 추가했다.
- object selection 전용 context menu에도 같은 z-order 액션을 추가했다.
- widget test와 command serialization test로 리본/context menu가 `changeObjectZOrder` envelope를 전달하는지 검증했다.

## 이 작업을 진행한 이유

직전 단계에서 object/control 선택과 삭제가 가능해졌지만, 실제 문서 편집기에서는 겹치는 그림, 도형, 글상자의 앞뒤 순서를 바꾸는 동작도 기본 편집 기능이다. vendored rhwp core에는 이미 shape z-order 변경 API가 있으므로, WebView의 upstream editor에만 의존하지 않고 Flutter-native editor에서 같은 편집 의도를 실행할 수 있게 연결했다.

## 배울점

- Flutter-native editor는 화면 overlay selection을 command target으로 바꾸는 작은 계약을 계속 확장해야 한다. z-order는 문서 내용을 직접 입력하지 않지만 렌더링 결과를 바꾸는 편집 command이므로 undo-aware `_runEdit` 경로를 써야 한다.
- object selection을 삭제하지 않고 유지하면 사용자가 여러 z-order 동작을 연속 실행할 수 있다.
- 현재 rhwp core의 z-order API는 shape 중심이므로 picture/image 타입은 shape path로 우선 라우팅하고, 실패 시 명시적인 오류를 반환하는 편이 안전하다.

## 검증

- `dart format --set-exit-if-changed lib/src/rhwp_document.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `flutter test test/flutter_rhwp_test.dart --plain-name "object control commands serialize to Rust envelopes"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor edit ribbon changes selected object z order"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu changes selected object z order"`
- `flutter analyze`
- `flutter test`
- `(cd example && flutter test)`
- `cargo fmt --check`
- `cargo test applies_commands_exports_and_reopens`
- `cargo test`
