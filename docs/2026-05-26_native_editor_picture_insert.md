# Native Editor Picture Insert

## 작업한 내용

- `insertPicture` 명령을 Dart `RhwpCommand`, `RhwpDocument`, Rust facade에 추가했다.
- vendored rhwp core의 `insert_picture_native`를 Flutter-native editor에서 호출하도록 연결했다.
- `RhwpNativeEditor`에 `onImageRequested` 콜백을 추가해 앱이 파일 선택/권한 처리를 맡고 editor는 이미지 bytes를 문서 command로 삽입하도록 했다.
- 입력 리본에 그림 삽입 버튼을 추가하고, example 앱에서는 기존 `file_picker`로 PNG/JPEG/BMP/GIF 파일을 선택해 삽입할 수 있게 했다.
- command 직렬화, document convenience API, widget toolbar flow, Rust facade 회귀 테스트를 추가했다.

## 이 작업을 진행한 이유

- upstream 웹 에디터의 입력 리본에는 그림 삽입이 있고, HWP 편집기에서 그림은 텍스트/표/수식만큼 기본적인 객체 입력 기능이다.
- Flutter-native editor가 WebView fallback 없이 실제 문서 편집기로 확장되려면 object selection/editing뿐 아니라 object creation도 Flutter UI에서 시작할 수 있어야 한다.
- 파일 선택은 플랫폼별 권한과 UX가 다르므로 플러그인 코어에 file picker를 고정하지 않고 앱 콜백으로 분리하는 구조가 유지보수에 유리하다.

## 이 작업을 통해 배울 점

- Rust core가 이미 제공하는 mutation API는 JSON command envelope로 노출하면 Flutter UI에서 단계적으로 기능을 키울 수 있다.
- 이미지 bytes처럼 큰 입력은 장기적으로 전용 FRB API로 분리할 여지가 있지만, 현재 command 기반 editor 흐름에서는 동일 undo/render refresh 경로를 재사용하는 장점이 있다.
- editor widget은 파일 시스템 접근을 직접 소유하지 않고, 앱이 bytes와 metadata를 제공하게 하면 Web, desktop, mobile의 차이를 더 안전하게 흡수할 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor insert ribbon inserts a picture"`
- `flutter test test/rhwp_widget_test.dart`
- `cargo test -p flutter_rhwp --lib`
- `flutter analyze`
