# 2026-05-25 Export Surface Completion

## 작업한 내용

- `RhwpExportFormat`에 `text`, `markdown`, `svg`를 추가했다.
- `RhwpDocument.export()`가 HWP/HWPX/PDF/DOCX뿐 아니라 텍스트, Markdown, 페이지 SVG도 `Uint8List`로 반환하도록 확장했다.
- `exportText()`, `exportMarkdown()`, `exportPageSvg()` 편의 메서드를 추가해 문자열 추출 API와 파일 저장 API 사이의 중복 코드를 줄였다.
- 예제 앱의 export 메뉴에 SVG 저장 항목을 추가하고, TXT/MD 저장도 새 공개 export API를 사용하도록 정리했다.
- Dart 단위 테스트에서 PDF, text, Markdown, SVG export forwarding과 page 인자 전달을 검증하도록 보강했다.

## 이 작업을 진행한 이유

- 초기 전환 계획의 보장 변환 범위는 text, Markdown, SVG, HWP, HWPX, PDF, DOCX였지만 공개 `RhwpExportFormat`은 일부 바이너리 형식만 표현하고 있었다.
- 예제 앱이 텍스트와 Markdown을 직접 UTF-8 bytes로 변환하면 앱마다 같은 변환 코드를 반복해야 한다.
- SVG는 이미 렌더링 API로 받을 수 있었지만 파일 저장/다운로드 흐름에는 노출되지 않아, "보기"와 "내보내기" 기능 사이에 빠진 부분이 있었다.

## 이 작업을 통해 배울점

- Flutter 플러그인의 공개 API는 코어 기능만 감싸는 수준을 넘어서, 앱에서 실제 파일 저장 흐름에 바로 연결할 수 있는 bytes 기반 메서드를 제공하는 편이 사용성이 좋다.
- 페이지 단위 결과인 SVG와 문서 또는 페이지 단위 결과가 모두 가능한 text/Markdown은 같은 export API에 올리되, `page` 옵션을 명시적으로 전달할 수 있게 해야 한다.
- 예제 앱이 공개 API를 직접 사용하면, 예제가 문서 역할과 회귀 테스트 역할을 함께 할 수 있다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test`
- `flutter analyze`
- `cd example && flutter test`
