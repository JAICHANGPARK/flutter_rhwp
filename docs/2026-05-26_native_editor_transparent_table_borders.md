# 2026-05-26 Native Editor Transparent Table Borders

## 작업한 내용

- Flutter-native 에디터 상태에 투명 표 경계 표시 토글을 추가했다.
- 보기 리본에 Transparent table borders 버튼을 추가했다.
- page layer tree의 `tableCell` bounds를 Flutter overlay에서 점선 경계로 렌더링하도록 연결했다.
- 투명 표 경계 토글 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream rhwp web editor는 편집 보조 기능으로 투명선 표시 토글을 제공한다. Flutter-native 에디터가 WebView 에디터를 대체하려면 실제 문서 출력에는 영향을 주지 않는 편집용 표시 기능도 Flutter 위젯으로 구현되어야 한다.

## 이 작업을 통해 배울점

- 렌더링 결과를 바꾸는 기능과 편집 보조 overlay 기능은 분리해서 설계하는 편이 안전하다.
- `pageLayerTree`의 표 셀 bounds를 활용하면 Rust core 명령을 추가하지 않고도 Flutter overlay에서 편집 보조 표시를 만들 수 있다.
- 표시 토글은 문서 상태를 변경하지 않으므로 `applyCommand` 없이 로컬 UI 상태와 overlay 테스트로 검증할 수 있다.

## 검증

- `dart format`
- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`

Flutter widget test 실행은 sandbox에서 localhost test server socket 생성이 막혀 실패할 수 있다.
