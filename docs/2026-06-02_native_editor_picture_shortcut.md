# Native editor picture shortcut

## 작업한 내용

- Flutter-native editor에 `Ctrl/Cmd+Alt+I` 그림 삽입 단축키를 추가했다.
- 기존 `_insertPicture` 경로를 재사용해 input ribbon과 body context menu의 그림 삽입 동작과 같은 command path를 공유하도록 했다.
- 일반 `Ctrl/Cmd+I` 기울임 단축키와 충돌하지 않도록 Alt가 함께 눌린 경우에만 그림 삽입을 실행한다.
- shortcut으로 image picker callback을 호출하고 `insertPicture` 명령이 생성되는 widget test를 추가했다.
- README와 CHANGELOG에 그림 삽입 단축키 지원 내용을 반영했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 editor가 WebView fallback 없이 실제 HWP 편집기로 쓰이려면 텍스트와 표뿐 아니라 그림 같은 문서 객체 삽입도 키보드 흐름에서 접근 가능해야 한다. 이미지 파일 선택과 권한 처리는 앱 콜백에 맡기고, editor는 기존 Rust command path를 호출하도록 유지해 플랫폼별 차이를 줄였다.

## 이 작업을 통해 배울점

- `Ctrl/Cmd+I`는 italic 토글로 유지해야 하므로 그림 삽입은 `Ctrl/Cmd+Alt+I`로 먼저 분기해야 한다.
- shortcut, ribbon, context menu가 `_insertPicture`를 공유하면 image byte normalization, 크기 계산, cursor update 규칙을 중복 구현하지 않아도 된다.
- 그림 삽입 테스트는 picker callback의 결과가 extension 정규화와 command JSON으로 이어지는지 함께 확인해야 한다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor inserts a picture with shortcut"`
- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart test/rhwp_widget_test.dart`
