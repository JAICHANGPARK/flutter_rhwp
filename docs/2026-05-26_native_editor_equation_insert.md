# Native Editor Equation Insert

## 작업한 내용

- `insertEquation` 명령을 Dart `RhwpCommand`와 Rust facade에 추가했다.
- vendored rhwp 코어의 `insert_equation_native`를 Flutter-native editor에서 직접 호출하도록 연결했다.
- `입력` 리본에 수식 삽입 버튼과 Flutter 수식 대화상자를 추가했다.
- 대화상자에서 수식 스크립트, 글자 크기, 색상을 입력하고 본문 커서 위치에 수식 컨트롤을 삽입하도록 했다.
- command 직렬화, 문서 convenience API, Flutter widget flow, Rust facade 회귀 테스트를 추가했다.

## 이 작업을 진행한 이유

- upstream 웹 에디터의 입력 기능을 WebView 없이 Flutter 위젯 기반으로 옮기는 과정에서 표/각주 외의 객체형 입력 기능도 필요하다.
- 수식은 HWP 문서의 전용 컨트롤이므로, Flutter UI는 입력과 명령만 담당하고 실제 생성/레이아웃은 rhwp Rust 코어가 처리하는 구조가 맞다.

## 이 작업을 통해 배울 점

- Flutter-native editor는 복잡한 문서 객체라도 core에 이미 있는 mutation API를 FRB command로 노출하면 단계적으로 확장할 수 있다.
- 색상, 글자 크기처럼 UI 단위와 core 단위가 다른 값은 대화상자에서 명확히 변환해 넘겨야 한다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toolbar applies insert and delete commands"`
- `cargo test -p flutter_rhwp --lib`
