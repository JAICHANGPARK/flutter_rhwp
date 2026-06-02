# Native editor table shortcut

## 작업한 내용

- Flutter-native editor에 `Ctrl/Cmd+Alt+T` 표 만들기 단축키를 추가했다.
- 기존 `_insertTable` 경로를 재사용해 input ribbon과 body context menu의 표 삽입 동작과 같은 command path를 공유하도록 했다.
- 일반 `Alt+T` 문단 모양 단축키와 충돌하지 않도록 `Ctrl/Cmd`가 함께 눌린 경우에만 표 삽입을 실행한다.
- shortcut으로 기본 2x2 표를 만들 때 `insertTable` 명령이 생성되는 widget test를 추가했다.
- README와 CHANGELOG에 표 삽입 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 editor가 WebView fallback 없이 문서 작성 도구로 쓰이려면 표 삽입처럼 자주 쓰는 구조 입력도 toolbar 클릭에만 묶여 있으면 안 된다. 이미 Rust command와 Flutter ribbon 경로가 있으므로 shortcut 진입점을 추가해 native editor의 키보드 중심 편집 흐름을 넓혔다.

## 이 작업을 통해 배울점

- `Alt+T`는 paragraph shape dialog로 유지해야 하므로 표 삽입은 `Ctrl/Cmd+Alt+T` 조합으로 분리해야 한다.
- shortcut, ribbon, context menu가 `_insertTable`을 공유하면 rows/columns, inline table 설정, cursor update 규칙이 한 경로에 유지된다.
- 표 삽입 테스트는 command뿐 아니라 삽입 뒤 cursor가 다음 문단으로 이동하는지 함께 확인해야 문서 편집 흐름을 검증할 수 있다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor inserts a table with shortcut"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
