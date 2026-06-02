# 2026-06-02 native editor ruler

## 작업한 내용

- Flutter-native editor에 가로 ruler 위젯을 추가했다.
- View 리본에 `Ruler` 토글 버튼을 추가해서 ruler 표시 상태를 켜고 끌 수 있게 했다.
- ruler는 문서 편집 명령이 아니므로 undo snapshot, `onChanged`, Rust command 호출 없이 순수 Flutter 표시 상태로만 동작하게 했다.
- widget test로 기본 숨김, 토글 표시/숨김, command 미발생을 검증했다.

## 이 작업을 진행한 이유

WebView 기반 rhwp editor를 Flutter 위젯으로 대체하려면 입력 명령뿐 아니라 에디터 화면을 구성하는 chrome도 Flutter에서 갖춰야 한다. upstream rhwp editor는 view 레이어에 ruler/status/canvas 같은 편집 화면 요소를 두고 있으므로, native editor도 같은 방향으로 독립적인 편집 화면 구성을 쌓아가야 한다.

## 이 작업을 통해 배울점

- 편집 UI는 문서 모델을 바꾸는 기능과 화면 표시 상태를 명확히 분리해야 한다.
- ruler 같은 view chrome은 Rust core command 없이 Flutter 상태와 painter만으로 구현할 수 있다.
- WebView 제거는 한 번에 전체 UI를 옮기는 방식보다 toolbar, ruler, status bar, overlay 같은 화면 단위를 누적해 가는 방식이 유지보수에 유리하다.

## 검증

- `dart format`
- `flutter test test/rhwp_widget_test.dart --name "view ribbon toggles the native ruler"`
- `flutter analyze`
