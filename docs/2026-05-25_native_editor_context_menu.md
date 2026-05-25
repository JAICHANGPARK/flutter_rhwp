# Native Editor Context Menu

## 작업한 내용

- `RhwpNativeEditor` page overlay에서 secondary click을 처리하도록 했다.
- 텍스트 선택 영역 안에서 우클릭하면 기존 선택을 유지한 채 context menu를 띄운다.
- 표 셀 위에서 우클릭하면 해당 셀을 선택하고, 표 전용 context menu를 띄운다.
- Flutter `showMenu` 기반 메뉴를 추가했다.
  - 일반 문서 문맥: 잘라내기, 복사, 붙여넣기, 굵게, 기울임, 밑줄, 문단 정렬, 표 만들기
  - 표 셀 문맥: 붙여넣기, 줄 삽입, 칸 삽입, 셀 합치기, 셀 나누기
- context menu에서 복사를 실행하면 page layer tree selection text를 통해 클립보드에 텍스트를 넣도록 검증했다.
- context menu에서 `셀 나누기`를 실행하면 선택된 표 셀의 Rust command envelope가 생성되도록 검증했다.

## 이 작업을 진행한 이유

WebView 기반 `RhwpFullEditor`는 upstream web editor의 DOM/Canvas 이벤트 레이어를 그대로 쓴다. 하지만 Flutter-native editor는 입력, 선택, 서식, 표 편집 문맥을 Flutter 위젯과 이벤트로 다시 만들어야 한다.

기존 Flutter-native editor에는 keyboard shortcut과 ribbon toolbar가 있었지만, 문서 위에서 바로 실행하는 편집 문맥 메뉴가 없었다. 실제 에디터에서는 선택 영역과 표 셀을 기준으로 자주 쓰는 명령을 바로 띄우는 흐름이 중요하므로, 이번 작업에서 Flutter-native context menu를 추가했다.

## 이 작업을 통해 배울점

- Flutter-native editor는 `Listener`의 pointer button 정보를 이용해 Web DOM 이벤트 없이 secondary click을 처리할 수 있다.
- context menu를 띄우기 전에 hit testing 결과로 selection/table state를 먼저 맞춰야 메뉴 명령이 올바른 Rust command context로 실행된다.
- 표 셀 문맥은 일반 텍스트 문맥보다 메뉴 항목을 줄이는 편이 화면 안에 안정적으로 들어오고, 사용자가 필요한 표 작업에 더 빠르게 접근할 수 있다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu copies selected text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu runs table cell actions"`
- `flutter test test/rhwp_widget_test.dart`
- `flutter test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
