# 2026-05-25 native editor object hit testing

## 작업한 내용

- `RhwpLayerTree`에서 bounded `shape`, `image`, `control`, `object` 계열 node를 `RhwpObjectLayout`으로 노출했다.
- page-coordinate point로 가장 작은 object/control을 찾는 `objectForPoint` helper를 추가했다.
- `RhwpNativeEditor` controller에 object selection state를 추가했다.
- Flutter page overlay에서 object/control click selection과 selection border highlighting을 구현했다.
- Escape로 selected object state가 정리되도록 했다.
- widget/unit test로 layer-tree object parsing, object hit-test, overlay highlight, command 미발생을 검증했다.

## 이 작업을 진행한 이유

- Flutter-native editor 포팅에서 object hit-test는 upstream web editor와 동등해지기 위한 핵심 난점 중 하나다.
- 기존 native editor는 text와 table cell만 page layer tree에서 hit-test했고, shape/image/control 같은 bounded object는 선택할 방법이 없었다.
- object selection은 첫 단계에서는 문서를 수정하지 않는 view/editor state로 처리하고, 이후 resize/move/delete command로 확장하는 구조가 맞다.

## 이 작업을 통해 배울점

- page layer tree는 upstream JSON shape가 변할 수 있으므로 object parsing도 tolerant한 type/bounds 기반으로 시작하는 것이 안전하다.
- table cell, object, text hit-test는 우선순위가 필요하다. table cell을 먼저 처리하고, 그 다음 object, 마지막 text caret 순서로 두면 기존 표 편집 UX를 깨지 않는다.
- object selection은 Flutter overlay state와 controller state를 분리하지 않고 같은 controller에 올려야 Escape, toolbar, 향후 object command가 같은 source of truth를 쓸 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart --plain-name "page layer tree model flattens tolerant layer JSON"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "page layer tree model maps table cell hit context"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor selects objects from page layer tree"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor taps table cell to set table edit context"`
- `dart format --set-exit-if-changed lib/src/rhwp_layer_tree.dart lib/src/rhwp_editor.dart test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
- `git diff --check`
- `flutter analyze`
- `flutter test`
- `flutter test` in `example/`
- `cargo fmt --check` in `rust/`
- `cargo test` in `rust/`
