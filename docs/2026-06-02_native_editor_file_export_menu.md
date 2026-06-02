# Native editor file export menu

## 작업한 내용

- Flutter-native file ribbon에 추가 export menu를 붙였다.
- 기존 `onExported` callback을 재사용해 DOCX, text, Markdown, current-page SVG export artifact를 앱으로 전달하도록 했다.
- SVG export는 현재 editor page를 넘겨 `sample-page-1.svg`처럼 page suffix가 붙는 저장 이름을 만들도록 했다.
- widget test에서 HWP/HWPX/PDF 빠른 export와 DOCX/TXT/MD/SVG 메뉴 export가 모두 편집 command 없이 save artifact만 만드는지 검증했다.

## 이 작업을 진행한 이유

패키지 전체 export API는 HWP, HWPX, PDF, DOCX, text, Markdown, SVG를 지원하지만 Flutter-native editor의 file ribbon은 HWP/HWPX/PDF만 직접 노출하고 있었다. WebView full editor를 fallback으로 유지하더라도 native editor가 실제 편집 surface가 되려면 파일 리본 안에서 지원 export 형식에 접근할 수 있어야 한다.

SVG는 문서 전체 파일이 아니라 페이지 단위 결과물이므로 현재 페이지를 명시적으로 넘기게 했다. 이렇게 해야 파일명과 export 대상이 editor 상태와 일치한다.

## 이 작업을 통해 배울점

- export menu는 새 저장 API를 만들기보다 기존 `RhwpDocument.exportDocument()`와 `onExported` 경계를 공유하는 편이 안전하다.
- page-scoped export는 editor controller의 현재 페이지 상태와 연결해야 사용자가 보고 있는 페이지를 저장한다는 기대에 맞는다.
- 파일 리본 export는 문서를 수정하지 않으므로 undo snapshot이나 Rust edit command가 발생하지 않는지 테스트해야 한다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon exports save artifacts"
```
