# 2026-05-26 native editor object aspect resize

## 작업한 내용

- `RhwpNativeEditor`의 selected object corner resize handle에서 Shift+drag를 감지한다.
- Shift가 눌린 경우 원래 object bounds의 width/height 비율을 유지하도록 resize bounds를 보정한다.
- 보정된 bounds는 기존 object properties bridge command로 커밋되므로 저장/undo/onChanged 흐름은 기존 object resize와 동일하게 유지된다.
- widget test로 south-east handle을 수평으로만 이동해도 Shift 상태에서는 높이가 함께 늘어나 원래 비율이 유지되는지 검증했다.

## 이 작업을 진행한 이유

WebView 없는 Flutter-native editor가 실제 WYSIWYG 편집기에 가까워지려면 개체 조작도 단순 이동/리사이즈를 넘어 modifier 기반 편집 UX를 가져야 한다. 이미지와 도형은 비율 유지 리사이즈가 기본적인 편집 동작이므로 Flutter overlay 단계에서 처리했다.

## 이 작업을 통해 배울 점

- object resize preview는 Flutter overlay state에서 즉시 계산하고, pointer-up 시점에 Rust command로 커밋하는 구조가 자연스럽다.
- modifier key 상태는 pointer move 시점의 `HardwareKeyboard` 상태를 보고 적용해야 drag 중 Shift 입력 변화에도 대응할 수 있다.
- aspect ratio 보정은 page coordinate bounds에서 먼저 처리한 뒤 기존 object property 매핑을 재사용하면 Rust command surface를 늘리지 않아도 된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor preserves object ratio with shift resize"`
