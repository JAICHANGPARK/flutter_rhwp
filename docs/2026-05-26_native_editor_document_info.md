# 2026-05-26 native editor document info

## 작업한 내용

- Flutter-native editor의 파일 리본에 문서 정보 버튼을 추가했다.
- 버튼을 누르면 `RhwpDocument.metadata()`를 통해 Rust 세션의 문서 메타데이터를 읽고 Flutter dialog로 표시한다.
- dialog에는 파일명, 문서 형식, 페이지 수, raw metadata JSON을 보여준다.
- widget test에서 파일 리본 버튼, dialog 표시, metadata 값, command 미발행을 검증했다.

## 이 작업을 진행한 이유

upstream web editor에는 파일 정보 팝업이 있고, native editor에서도 WebView 없이 문서 상태를 확인할 수 있어야 한다. 이미 Rust bridge가 문서 metadata를 제공하고 있으므로 JS 경로를 만들 필요 없이 Flutter UI만 추가하면 된다.

## 이 작업을 통해 배울 점

- 조회성 기능은 편집 command와 분리해서 `onChanged`나 undo snapshot을 건드리지 않게 유지해야 한다.
- Flutter-native editor의 file ribbon은 open/save/export뿐 아니라 문서 상태 확인 기능까지 모아두는 편이 사용 흐름에 맞다.
- raw metadata를 함께 보여두면 facade가 제공하는 정보 확장 시 디버깅과 검증에 도움이 된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon shows document info"`
- `flutter test test/rhwp_widget_test.dart`
- `flutter analyze`
- `git diff --check`
