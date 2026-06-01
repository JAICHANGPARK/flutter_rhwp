# Native Editor Typing Repaint Isolation

## 작업한 내용

- Flutter-native editor의 pending text preview, caret, IME composing preview를 각각 `RepaintBoundary`로 감쌌다.
- 빠른 텍스트 입력 테스트에서 pending text preview와 caret가 별도 repaint boundary 아래에 있는지 검증했다.
- `CHANGELOG.md`에 입력 overlay repaint 격리 작업을 기록했다.

## 이 작업을 진행한 이유

예제 앱에서 Space나 텍스트를 입력할 때 화면이 refresh되는 것처럼 보이는 문제가 있었다. 기존 코드는 SVG 재렌더 자체는 지연하고 있었지만, 입력 중 계속 변하는 pending text, caret blink, IME composing preview가 같은 overlay repaint 범위 안에 있었다.

Flutter-native editor는 WebView fallback을 유지하면서도 네이티브 위젯 에디터로 커져야 하므로, 입력 중에는 문서 페이지 SVG와 입력 overlay의 repaint 범위를 명확히 분리해야 한다.

## 이 작업을 통해 배울점

- 텍스트 입력 최적화는 문서 명령 지연만으로 충분하지 않다. 실제 사용자가 느끼는 refresh는 repaint 범위에서도 발생할 수 있다.
- HWP 페이지 렌더링처럼 무거운 표면은 입력 caret, 조합 문자열, pending text preview와 별도 paint boundary를 가져야 한다.
- Flutter-native editor는 Rust core를 source of truth로 두되, UI 입력 반응성은 Flutter 렌더 트리 단위에서 별도로 관리해야 한다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor previews rapid text while an insert command is pending"`
- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart`
