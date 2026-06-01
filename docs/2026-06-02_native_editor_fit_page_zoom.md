# Native Editor Fit Page Zoom

## 작업한 내용

- `RhwpViewerController.fitPage()`를 추가했다.
- mounted `RhwpViewer`가 현재 페이지 RenderBox 높이와 viewport 높이를 기준으로 fit-page zoom을 계산하도록 연결했다.
- Flutter-native editor의 보기 리본과 상태바에 `Fit page` 버튼을 추가했다.
- controller fallback, viewer viewport 계산, native editor 버튼 연결을 widget test로 검증했다.

## 이 작업을 진행한 이유

upstream HWP editor에는 page-width 보기뿐 아니라 페이지 전체를 화면에 맞춰 보는 흐름이 있다. Flutter-native editor가 WebView fallback 없이 실제 편집 화면으로 성장하려면 보기/탐색 UX도 Flutter 위젯 안에서 동작해야 한다.

기존 `fitWidth()`는 100% zoom으로 page-width fit을 표현했지만, 전체 페이지 맞춤은 viewport 높이와 현재 페이지 높이를 알아야 한다. 그래서 controller에 고정 preset을 넣지 않고, viewer가 mounted layout 정보를 계산해주는 구조로 구현했다.

## 이 작업을 통해 배울점

- Flutter-native viewer에서 레이아웃 의존 기능은 controller 단독 계산보다 mounted widget의 RenderBox 정보를 이용하는 편이 정확하다.
- fit-page는 문서 편집 명령이 아니므로 Rust command나 undo/onChanged 경로를 건드리지 않고 viewer 상태만 바꾸는 것이 맞다.
- Web editor 기능을 Flutter로 옮길 때도 DOM API를 흉내 내기보다 Flutter의 layout/controller 모델에 맞춰 다시 설계해야 한다.

## 검증

- `dart format lib/src/rhwp_viewer.dart lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpViewer fit page uses the current viewport height"`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor view controls synchronize zoom state"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
