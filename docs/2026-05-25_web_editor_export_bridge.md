# 2026-05-25 Web Editor Export Bridge

## 작업한 내용

- `RhwpWebEditorController`를 추가해 Web에서 임베드한 upstream `@rhwp/editor` 인스턴스와 Dart 코드를 연결했다.
- controller는 mounted editor의 `exportHwp`, `exportHwpx`, `exportPdf`, `exportDocx`, `exportText`, `exportMarkdown`, `exportSvg` 계열 메서드를 찾아 호출하고, 반환값을 `Uint8List`로 정규화한다.
- 예제 앱의 export 버튼은 Web editor 모드일 때 Flutter bridge 문서가 아니라 `RhwpWebEditorController`를 통해 upstream editor의 현재 상태를 저장하도록 바꿨다.
- non-Web 환경에서는 같은 API가 `RhwpUnsupportedPlatformException`을 던지도록 stub을 맞췄다.
- README와 CHANGELOG에 Web editor export controller 사용법과 제약을 반영했다.

## 이 작업을 진행한 이유

- Web editor 토글만 있으면 화면에서 편집한 내용과 상단 export/save 버튼이 서로 다른 문서 상태를 볼 수 있다.
- 사용자가 기대하는 Web editor 모드는 upstream `@rhwp/editor`의 완성형 편집 UI를 쓰면서, 저장/다운로드도 그 editor 상태를 기준으로 동작하는 것이다.
- upstream editor의 export API는 빌드 버전별로 노출 메서드가 다를 수 있으므로, 플러그인 쪽에서 후보 메서드를 순서대로 시도하고 명확한 unsupported 오류를 돌려줘야 한다.

## 이 작업을 통해 배울점

- Flutter Web의 `HtmlElementView`는 JS 객체 생명주기와 Dart widget 생명주기를 따로 관리해야 하므로 controller attach/detach 경계가 필요하다.
- 외부 ESM editor를 직접 번들하지 않는 구조에서는 export 지원 여부를 컴파일 타임에 보장할 수 없다. 런타임에 기능 탐지 후 실패 메시지를 명확히 주는 방식이 현실적이다.
- Web editor와 Flutter bridge는 같은 파일에서 시작하더라도 편집 이후에는 서로 다른 상태를 가질 수 있다. 사용자-facing save/export 경로는 현재 선택된 편집 surface를 기준으로 분기해야 한다.

## 검증

- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
- `flutter build web`
- `git diff --check`
