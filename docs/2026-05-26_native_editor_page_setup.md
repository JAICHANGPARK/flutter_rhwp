# Native Editor Page Setup

## 작업한 내용

- `getPageSetup`, `setPageSetup` 명령을 Dart `RhwpCommand`와 Rust facade에 추가했다.
- vendored rhwp 코어의 `get_page_def_native`, `set_page_def_native`를 Flutter-native editor에서 직접 호출하도록 연결했다.
- `쪽` 리본의 `Page setup` 버튼을 활성화하고, 용지 크기, 여백, 머리말/꼬리말 거리, 제본 여백, 방향, 제본 방식을 설정하는 Flutter 대화상자를 추가했다.
- 공개 Dart API에 `RhwpPageSetup`, `RhwpDocument.pageSetup`, `RhwpDocument.setPageSetup`을 추가했다.
- command 직렬화, widget flow, Rust facade 회귀 테스트를 보강했다.

## 이 작업을 진행한 이유

- upstream 웹 에디터의 `쪽` 관련 기능을 WebView 없이 Flutter 위젯으로 재구현하기 위한 첫 단계다.
- 페이지 설정은 렌더링, 편집 좌표, 머리말/꼬리말 영역에 직접 영향을 주므로 Flutter-native editor가 Rust 코어의 Section/PageDef를 직접 제어할 수 있어야 한다.

## 이 작업을 통해 배울 점

- Flutter-native editor는 JS API를 호출하지 않고도 FRB `applyCommand` 경로만 확장하면 기존 rhwp 코어 기능을 재사용할 수 있다.
- 사용자 UI는 mm 단위로 받되, 코어에는 HWPUNIT 원본값을 전달하는 식으로 도메인 단위와 화면 단위를 분리하는 편이 안전하다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor page ribbon applies page setup"`
- `cargo test -p flutter_rhwp --lib`
