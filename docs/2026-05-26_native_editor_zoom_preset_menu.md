# 2026-05-26 native editor zoom preset menu

## 작업한 내용

- Flutter-native editor의 view ribbon zoom 표시를 preset 선택 메뉴로 바꿨다.
- 상태바의 zoom 표시도 같은 preset 선택 메뉴로 바꿨다.
- 두 메뉴 모두 `25%, 50%, 75%, 100%, 125%, 150%, 200%, 300%` 목록을 사용하고, 현재 배율에는 체크 표시를 보여준다.
- zoom menu 선택이 controller zoom, toolbar 표시, status bar 표시를 함께 갱신하는 회귀 테스트를 추가했다.
- README와 CHANGELOG에 zoom preset menu 동작을 반영했다.

## 이 작업을 진행한 이유

upstream web editor에는 배율 메뉴가 있고, 사용자가 원하는 비율을 직접 선택할 수 있다. 직전 작업에서 Flutter-native editor의 zoom 이동 단계는 upstream preset에 맞췄지만, 직접 preset을 고르는 UI는 아직 없었다.

view ribbon과 status bar 양쪽에서 같은 zoom preset 메뉴를 제공하면 WebView fallback과 Flutter-native editor 사이의 보기 조작 방식이 더 가까워진다.

## 이 작업을 통해 배울 점

- editor controller의 zoom 상태는 toolbar, status bar, keyboard shortcut, mouse wheel이 모두 공유해야 한다.
- 표시 텍스트를 단순 label이 아니라 menu trigger로 만들면 작은 UI 변화로 upstream 기능에 가까운 조작성을 제공할 수 있다.
- 같은 preset 목록은 controller 상수를 참조해야 추후 preset 변경 시 UI가 서로 어긋나지 않는다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor view controls synchronize zoom state"`은 sandbox의 `127.0.0.1:0` socket 생성 제한 때문에 실행 환경에서 막힌다.
