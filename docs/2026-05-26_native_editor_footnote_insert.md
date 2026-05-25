# Native Editor Footnote Insert

## 작업한 내용

- `insertFootnote` 명령을 Dart `RhwpCommand`와 Rust facade에 추가했다.
- vendored rhwp 코어의 `insert_footnote_native`를 Flutter-native editor에서 직접 호출하도록 연결했다.
- `입력` 리본에 각주 삽입 버튼을 추가하고, 본문 커서 위치에 각주 컨트롤을 삽입하도록 했다.
- command 직렬화, 문서 convenience API, Flutter widget flow, Rust facade 회귀 테스트를 추가했다.

## 이 작업을 진행한 이유

- upstream 웹 에디터의 입력 기능을 WebView 없이 Flutter 위젯 기반으로 옮기는 과정에서 각주처럼 문서 구조를 바꾸는 기능이 필요하다.
- 각주는 단순 텍스트 삽입보다 문단 컨트롤, 번호 재계산, 페이지네이션에 더 깊게 연결되므로 Rust 코어를 source of truth로 두는 구조를 검증하기 좋다.

## 이 작업을 통해 배울 점

- Flutter-native editor는 UI만 담당하고, 각주 번호와 내부 문단 생성 같은 도메인 로직은 rhwp 코어에 맡기는 편이 안전하다.
- 기능 단위를 작게 가져가면 WebView fallback을 유지하면서도 native editor 표면을 계속 넓힐 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toolbar applies insert and delete commands"`
- `cargo test -p flutter_rhwp --lib`
