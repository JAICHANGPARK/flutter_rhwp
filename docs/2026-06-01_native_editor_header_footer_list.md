# Flutter-native editor header/footer list

## 작업한 내용

- rhwp core의 `get_header_footer_list_native`와 `delete_header_footer_native`를 `getHeaderFooterList`, `deleteHeaderFooter` command envelope로 노출했다.
- Dart `RhwpHeaderFooterList`, `RhwpHeaderFooterListItem`, `RhwpDocument.headerFooterList()`, `RhwpDocument.deleteHeaderFooter()`를 추가했다.
- `RhwpNativeEditor`의 `쪽` 리본에 머리말/꼬리말 목록 dialog를 추가하고, 선택한 항목을 삭제할 수 있게 했다.
- README, CHANGELOG, Rust/Dart/widget test를 갱신했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView 기반 full editor를 대체해 가려면 머리말/꼬리말을 생성하고 텍스트를 넣는 수준을 넘어, 문서에 이미 들어 있는 header/footer control을 확인하고 삭제하는 관리 흐름도 필요하다. upstream core에는 해당 API가 이미 있으므로 JS editor를 호출하지 않고 FRB command로 직접 연결했다.

## 이 작업을 통해 배울점

- Flutter 위젯 에디터는 리본 버튼 하나가 아니라 command 조회, 선택 dialog, 모델 삭제, 화면 refresh까지 한 흐름으로 묶어야 실제 편집 기능이 된다.
- Header/footer는 section, type, applyTo가 함께 target이 되므로 UI 목록에서도 이 정보를 보존해야 안전하게 삭제할 수 있다.
- WebView fallback을 유지하더라도 core API를 Flutter-native surface에 하나씩 연결하면 플랫폼별 WebView 의존도를 줄일 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor page ribbon deletes header footer controls"`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
