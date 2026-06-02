# 2026-06-02 native editor search refresh after undo

## 작업한 내용

- Flutter-native editor의 undo/redo snapshot restore 완료 후 active search matches를 다시 계산하도록 했다.
- text input으로 검색 결과가 사라진 뒤 undo로 문서 내용을 복원하면 search count와 active highlight도 복구되는 widget test를 추가했다.
- `CHANGELOG.md`에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

undo/redo는 문서 엔진 상태를 바꾸지만 기존 Flutter-native search state는 그대로 남을 수 있었다. WebView fallback 없이 Flutter 위젯 editor가 독립 편집 surface가 되려면 render state뿐 아니라 search count와 highlight 같은 파생 UI도 snapshot restore 이후의 문서 상태와 맞아야 한다.

## 이 작업을 통해 배울점

- undo/redo는 단순히 페이지를 다시 렌더링하는 것만으로 충분하지 않다. 검색, 선택, overlay처럼 layer tree를 기반으로 한 UI 상태도 다시 계산해야 한다.
- text input refresh와 snapshot restore는 서로 다른 edit 경로지만, search refresh helper를 공유하면 문서 상태 변경 후 파생 상태 동기화 규칙을 일관되게 유지할 수 있다.
- fake session 테스트에서는 undo 전후 page layer tree를 명시적으로 교체해 Rust core가 restore한 문서 상태를 모델링할 수 있다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor refreshes search matches after undo"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
