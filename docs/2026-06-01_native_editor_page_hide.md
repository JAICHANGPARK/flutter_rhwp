# Flutter-native editor page hide

## 작업한 내용

- rhwp core의 `get_page_hide_native`와 `set_page_hide_native`를 `getPageHide`, `setPageHide` command envelope로 노출했다.
- Dart `RhwpPageHide`, `RhwpCommand.getPageHide()`, `RhwpCommand.setPageHide()`, `RhwpDocument.pageHide()`, `RhwpDocument.setPageHide()`를 추가했다.
- `RhwpNativeEditor`의 `쪽` 리본에 `Page hide` 버튼과 설정 dialog를 추가했다.
- header, footer, master page, border, fill, page number 감추기 flag를 Flutter 위젯 UI에서 편집할 수 있게 했다.
- README, CHANGELOG, unit/widget test를 갱신했다.

## 이 작업을 진행한 이유

Flutter-native editor를 WebView fallback 없이 실제 HWP 편집 surface로 키우려면 본문 입력과 표 편집뿐 아니라 `쪽` 메뉴의 문서 출력/표시 제어 기능도 Flutter 위젯으로 옮겨야 한다. rhwp core에는 PageHide API가 이미 있으므로, JS editor를 호출하지 않고 FRB command로 노출하는 것이 현재 플러그인 구조와 맞다.

## 이 작업을 통해 배울점

- Web editor 포팅은 core에 있는 기능을 Flutter ribbon, dialog, cursor/paragraph target과 연결하는 반복 작업이다.
- 쪽 단위 기능도 실제로는 현재 문단에 PageHide control을 삽입하거나 갱신하는 모델 편집이므로, UI에서는 어떤 section/paragraph를 대상으로 할지 명확히 정해야 한다.
- command serialization, document convenience API, widget dialog test를 같은 커밋에 묶으면 Rust/Dart/Flutter 사이 계약이 어긋나는 일을 줄일 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor page ribbon applies page hide options"`
- `cargo check --manifest-path rust/Cargo.toml`
