# Native Editor Clipboard

## 작업한 내용

- `RhwpLayerTree`에 선택 범위의 텍스트를 추출하는 `textForRange` helper를 추가했다.
- text run이 선택 범위와 겹치는 구간만 잘라내고, paragraph가 바뀌는 지점에는 줄바꿈을 넣도록 했다.
- `RhwpNativeEditor`에서 Cmd/Ctrl+C, Cmd/Ctrl+X, Cmd/Ctrl+V 단축키를 처리하도록 했다.
- toolbar의 자르기, 복사, 붙여넣기 버튼을 실제 Flutter clipboard API와 연결했다.
- 잘라내기는 선택 텍스트를 clipboard에 쓴 뒤 기존 Rust delete command 흐름을 사용하고, 붙여넣기는 clipboard text를 Rust insert command로 commit하도록 했다.
- widget test와 layer-tree unit test로 선택 텍스트 추출, copy, cut, paste command dispatch를 검증했다.

## 이 작업을 진행한 이유

100% Flutter-native editor가 실제 문서 편집기로 가려면 키보드 입력과 caret 이동만으로는 부족하다.
사용자는 문서 편집에서 선택한 텍스트를 복사하거나 잘라내고 다른 위치에 붙여넣는 흐름을 기본 동작으로 기대한다.
WebView 기반 upstream editor에 의존하지 않고 Flutter 위젯 에디터를 키우려면 clipboard도 Flutter 입력/선택 모델과 Rust command 모델 사이에서 직접 연결해야 한다.

## 이 작업을 통해 배울점

- clipboard는 UI 기능처럼 보이지만 정확한 선택 범위 텍스트 추출이 먼저 준비되어야 한다.
- rendered SVG만으로는 선택 텍스트를 안정적으로 알 수 없으므로 page layer tree의 section, paragraph, offset 정보를 source of truth로 써야 한다.
- copy는 문서 모델을 바꾸지 않지만 cut/paste는 기존 delete/insert command와 같은 변경 경로를 공유해야 undo, dirty page rerender, cursor 갱신을 일관되게 확장할 수 있다.
- multi-page, table cell, object selection은 같은 구조 위에서 별도 selection domain으로 확장해야 한다.

## 검증

- `dart format lib/src/rhwp_layer_tree.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `flutter test --plain-name "RhwpNativeEditor copies cuts and pastes selected text"`
- `flutter test --plain-name "page layer tree model maps multi-paragraph selection ranges"`
- `flutter test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
