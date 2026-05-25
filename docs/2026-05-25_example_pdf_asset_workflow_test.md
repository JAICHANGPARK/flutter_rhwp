# Example PDF Asset Workflow Test

## 작업한 내용

- bundled HWP asset integration test에 PDF export 검증을 추가했다.
- native 플랫폼에서는 `RhwpDocument.exportDocument(RhwpExportFormat.pdf)`의 파일명,
  MIME type, PDF header, EOF marker를 확인한다.
- Web/WASM에서는 Flutter bridge PDF export가 명시적인
  `RhwpUnsupportedPlatformException` 경로로 남는지 확인한다.
- native PDF export가 실제 bundled asset에서는 30초를 넘길 수 있어 integration test
  timeout을 4분으로 명시했다.
- CHANGELOG에 PDF asset workflow 검증 추가를 기록했다.

## 이 작업을 진행한 이유

사용자는 example 앱에서 첨부한 HWP 파일을 읽고, 수정하고, 저장하고, PDF로 추출해
다운로드하는 흐름을 요청했다. 기존 integration test는 bundled asset을 열고 HWP/HWPX,
DOCX, text, Markdown, SVG export를 확인했지만 PDF export는 같은 asset workflow에서
직접 확인하지 않았다.

PDF는 사용자가 명시한 핵심 변환 결과물이라서, synthetic SVG나 blank fixture만으로는
예제 파일 기반 동작을 충분히 증명하기 어렵다. 이번 검증은 example의 저장/다운로드
메뉴가 사용하는 상위 export metadata API까지 확인한다.

## 이 작업을 통해 배울점

- feature가 UI에 노출되어 있어도, 실제 sample workflow로 검증하지 않으면 회귀를 놓칠 수
  있다.
- PDF 검증은 byte 전체를 비교하기보다 `%PDF-` header와 `%%EOF` marker처럼 안정적인 구조
  신호를 확인하는 편이 유지보수에 유리하다.
- Web/WASM 미지원 기능은 실패를 방치하지 말고 명시적인 unsupported exception으로 계약을
  고정해야 한다.
- 큰 문서의 PDF export는 느릴 수 있으므로 integration test에는 기능 특성에 맞는 timeout을
  명시해야 한다.

## 검증

- `dart format example/integration_test/asset_workflow_test.dart`
- `flutter test -d macos integration_test/asset_workflow_test.dart`
- `flutter test`
- `git diff --check`
