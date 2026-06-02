# Native editor shape shortcuts

## 작업한 내용

- Flutter-native editor에 `Ctrl/Cmd+Alt+R/O/L/X` 도형 preset 삽입 단축키를 추가했다.
- 단축키는 각각 rectangle, ellipse, line, text box 삽입으로 연결했다.
- 기존 `_insertShape` 경로를 재사용해 input ribbon과 body context menu의 도형 삽입 동작과 같은 command path를 공유하도록 했다.
- shortcut으로 네 가지 도형 preset을 삽입했을 때 `insertShape` 명령이 preset별 크기, wrap, type 값과 함께 생성되는 widget test를 추가했다.
- README와 CHANGELOG에 도형 삽입 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 editor가 WebView fallback 없이 실제 HWP 편집기로 쓰이려면 텍스트 입력뿐 아니라 그림, 표, 도형 같은 control 객체 입력도 키보드 중심 흐름에서 접근 가능해야 한다. 이미 Rust command와 Flutter ribbon/context menu 경로가 있으므로 shortcut 진입점을 추가해 native editor의 객체 삽입 범위를 넓혔다.

## 이 작업을 통해 배울점

- `Ctrl/Cmd+R/L/X`는 각각 정렬, 잘라내기 같은 기존 shortcut으로 쓰이므로 도형 삽입은 Alt 조합에서 먼저 분기해야 한다.
- shortcut, ribbon, context menu가 `_insertShape`를 공유하면 preset별 기본 크기, text wrap, treat-as-char, cursor 이동 규칙을 중복 구현하지 않아도 된다.
- 도형 preset 테스트는 shape type뿐 아니라 size/wrap/treat-as-char 값까지 확인해야 리본과 shortcut 경로의 동작 차이를 잡을 수 있다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor inserts shape presets with shortcuts"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
