# 2026-05-26 Native Editor Blinking Caret

## 작업한 내용

- Flutter-native 에디터의 caret overlay에 500ms 주기 blink 상태를 추가했다.
- caret 위치나 pending text overlay가 바뀌면 caret을 즉시 보이는 상태로 되돌리고 blink 타이머를 다시 시작하도록 했다.
- caret 위젯 key는 계속 유지하고 내부 opacity만 바꾸도록 구성해 hit-test와 기존 테스트 접근 방식을 유지했다.
- caret이 사라져 보이는 동안에도 `rhwp-editor-caret` hit target이 남아 있는지 확인하는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream rhwp web editor는 `text_selection.js`에서 caret을 500ms 간격으로 깜빡이게 처리한다. Flutter-native 에디터가 WebView 에디터를 대체하려면 텍스트 입력의 시각 피드백도 Flutter overlay에서 직접 구현해야 한다.

## 이 작업을 통해 배울점

- caret blink는 문서 상태와 무관한 순수 UI 상태이므로 Rust command나 render cache를 건드리지 않고 overlay state 안에 둘 수 있다.
- blink 중에도 caret 위젯을 tree에서 제거하지 않으면 탭/드래그 테스트와 geometry 계산이 안정적으로 유지된다.
- 위치가 바뀔 때 caret을 즉시 보이게 되돌리면 키보드 이동과 마우스 hit-test 이후 사용자가 새 위치를 바로 확인할 수 있다.

## 검증

- `dart format`
- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`

Flutter widget test 실행은 sandbox에서 localhost test server socket 생성이 막혀 실패할 수 있다.
