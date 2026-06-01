# Native editor paragraph indent shortcuts

## 작업한 내용

- Flutter-native editor에 `Ctrl/Cmd+BracketLeft`와 `Ctrl/Cmd+BracketRight` 단축키를 추가했다.
- 왼쪽 bracket은 문단 왼쪽 여백을 한 단계 줄이고, 오른쪽 bracket은 한 단계 늘린다.
- Shift 조합에서 들어올 수 있는 `BraceLeft`와 `BraceRight` logical key도 같은 경로로 처리했다.
- 기존 `_applyParagraphIndentDelta`와 `_paragraphIndentStep`을 재사용해 format ribbon, context menu, keyboard shortcut이 같은 paragraph-format command path를 공유하도록 했다.
- 선택된 여러 문단에 단축키가 `applyParaFormatRange`로 적용되는 widget test를 추가했다.
- README와 CHANGELOG에 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 editor가 WebView fallback을 점진적으로 대체하려면 서식 ribbon에 있는 기능을 키보드 중심 편집 흐름에서도 사용할 수 있어야 한다. 문단 들여쓰기 증감은 이미 native editor에 버튼과 command API가 있으므로, 같은 내부 경로를 재사용해 실제 편집 UX를 넓히는 데 적합하다.

## 이 작업을 통해 배울점

- bracket 키는 modifier 상태에 따라 `BracketLeft/BracketRight` 또는 `BraceLeft/BraceRight`로 들어올 수 있어 둘 다 처리하는 편이 안전하다.
- 문단 서식 단축키가 toolbar/context menu와 같은 `_applyParagraphFormat` 경로를 쓰면 본문 선택, 표 셀 선택, dirty refresh 처리가 분산되지 않는다.
- 들여쓰기 감소는 0 아래로 내려가지 않도록 기존 clamp 로직을 공유해야 한다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor applies paragraph indent shortcuts"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
