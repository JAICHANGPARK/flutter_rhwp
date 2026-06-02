# 2026-06-02 native editor search refresh after immediate edit

## 작업한 내용

- Flutter-native editor의 일반 non-deferred edit 완료 후 active search matches를 다시 계산하도록 했다.
- replace command처럼 자체적으로 search state를 갱신하는 경로는 중복 자동 refresh를 끄도록 분리했다.
- 검색 결과가 있는 paragraph를 edit ribbon에서 삭제한 뒤 search count와 active highlight가 사라지는 widget test를 추가했다.
- `CHANGELOG.md`에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

text input과 undo/redo는 search refresh가 붙었지만, 즉시 반영되는 toolbar/ribbon command edit는 render만 갱신하고 search overlay가 이전 layer tree 상태에 남을 수 있었다. Flutter 위젯 editor가 WebView fallback 없이도 독립 편집 surface가 되려면 모든 문서 변경 경로에서 render state와 search-derived UI state가 같은 문서 상태를 바라봐야 한다.

## 이 작업을 통해 배울점

- deferred text input, snapshot restore, immediate command edit는 refresh 타이밍이 다르지만 search-derived UI를 다시 계산해야 한다는 invariant는 같다.
- replace command는 search list를 직접 갱신하므로 generic search refresh와 중복 실행되지 않도록 옵션으로 분리해야 한다.
- layer tree 기반 overlay 테스트는 edit command 후 fake layer tree를 바꿔 실제 core 문서 변경 후 상태를 명시적으로 검증할 수 있다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor refreshes search matches after nondeferred edit"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
