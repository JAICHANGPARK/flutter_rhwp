# 2026-05-25 native editor file exports

## 작업한 내용

- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`에 `onExported` 콜백을 추가했다.
- Flutter-native 에디터의 파일 리본에서 HWP 저장, HWPX 저장, PDF 내보내기 버튼을 활성화했다.
- 파일 리본 버튼은 `RhwpDocument.exportDocument()`를 호출해 bytes, file name, MIME type이 포함된 `RhwpExportedDocument`를 앱 콜백으로 전달한다.
- widget test에서 파일 리본 HWP/HWPX/PDF export가 문서 변경 command 없이 save artifact만 생성하는 흐름을 검증했다.

## 이 작업을 진행한 이유

- upstream 웹 에디터는 파일을 열고 저장/내보내는 UX를 자체적으로 제공한다. Flutter-native 에디터가 WebView 의존을 줄이려면 파일 리본에서도 저장 결과를 앱으로 넘길 수 있어야 한다.
- 실제 파일 저장 위치 선택은 앱과 플랫폼별 파일 시스템 정책이 담당해야 하므로, 에디터 위젯은 bytes와 저장 메타데이터를 콜백으로 내보내는 구조가 맞다.
- 기존 `RhwpDocument.exportDocument()` 계약을 재사용하면 WebView, 예제 앱, Flutter-native 에디터의 save/download 흐름을 같은 데이터 모델로 맞출 수 있다.

## 이 작업을 통해 배울점

- Flutter-native 에디터의 파일 작업은 Rust command가 아니라 export API이므로 편집 명령 히스토리와 분리해야 한다.
- 위젯 내부에서 직접 파일 시스템을 다루지 않고 `RhwpExportedDocument`를 앱으로 넘기면 Web, mobile, desktop 저장 정책을 각각 자연스럽게 붙일 수 있다.
- 파일 리본은 Open/Save UI를 담는 shell이고, 실제 열기/저장 위치 선택은 example 또는 앱 레벨에서 구현하는 방식이 유지보수에 유리하다.

## 검증

- `RhwpNativeEditor` 파일 리본에서 HWP/HWPX/PDF 버튼을 누르면 `onExported`로 올바른 파일명과 bytes가 전달되는 widget test를 추가했다.
- export 동작이 `applyCommand`를 호출하지 않는 것을 확인해 저장과 편집 명령이 분리되어 있음을 검증했다.
