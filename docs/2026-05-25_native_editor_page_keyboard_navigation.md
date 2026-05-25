# 2026-05-25 native editor page keyboard navigation

## 작업한 내용

- `RhwpNativeEditor`에서 PageUp/PageDown 키 이동을 추가했다.
- 현재 caret이 포함된 page layer text run을 찾고, 이전/다음 page의 가까운 body text run으로 cursor를 이동한다.
- PageDown은 다음 page의 첫 body text run, PageUp은 이전 page의 마지막 body text run을 우선 선택한다.
- Shift+PageUp/PageDown은 기존 selection anchor를 유지한 채 page 단위로 선택을 확장한다.
- widget test로 PageDown, Shift+PageDown, PageUp 이동과 command 미발생을 검증했다.

## 이 작업을 진행한 이유

- 문서 편집기에서 page 단위 keyboard navigation은 긴 문서를 다룰 때 기본적인 탐색 UX다.
- Flutter-native 에디터가 WebView 없이 실제 편집 surface가 되려면 page viewport와 caret source position이 함께 움직여야 한다.
- 기존 ArrowUp/Down geometry helper를 재사용하면 page 이동도 page layer tree 기준으로 일관되게 처리할 수 있다.

## 이 작업을 통해 배울점

- page-level 이동은 cursor source position뿐 아니라 viewer controller의 current page 상태도 함께 갱신해야 한다.
- page layer tree에서 현재 caret run을 찾을 수 있으면 page 이동 후에도 비슷한 x 좌표를 유지할 수 있다.
- keyboard navigation은 문서를 수정하지 않으므로 edit command와 history가 발생하지 않는지 검증해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles page up and page down keys"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves vertically"`
- `dart format --set-exit-if-changed lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `git diff --check`
- `flutter analyze`
- `flutter test`
- `flutter test` in `example/`
- `cargo fmt --check` in `rust/`
- `cargo test` in `rust/`
