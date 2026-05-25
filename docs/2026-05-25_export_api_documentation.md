# Export API Documentation

## 작업한 내용

- `RhwpExportFormat`, `RhwpExportFormatMetadata`, `RhwpExportedDocument`에
  public API doc comment를 추가했다.
- `RhwpDocument.exportDocument()`에 저장/다운로드용 상위 export API라는 역할과
  platform unsupported 예외 조건을 문서화했다.
- `RhwpWebEditorController`의 Web/non-Web 구현에 같은 public 계약을 설명하는
  doc comment를 추가했다.
- CHANGELOG에 export API 문서화 작업을 반영했다.

## 이 작업을 진행한 이유

`flutter_rhwp`는 Flutter plugin으로 배포될 패키지이므로 public Dart API 자체가
사용자 문서의 일부가 된다. 특히 export API는 사용자가 직접 파일 저장, 브라우저
다운로드, MIME type 처리에 연결하는 영역이라 코드에서 계약이 분명해야 한다.

최근 `RhwpExportedDocument`와 `RhwpWebEditorController.exportDocument()`가 추가되어
Flutter bridge와 upstream Web editor mode가 같은 저장 metadata 계약을 공유하게
됐다. 이 계약을 README에만 두면 IDE hover, generated docs, pub.dev API 문서에서는
의미가 약해지므로 declaration-level documentation을 보강했다.

## 이 작업을 통해 배울점

- Flutter plugin의 public API는 README 예제뿐 아니라 Dart doc comment에서도
  사용 의도, 반환값, 예외 조건이 드러나야 한다.
- conditional export 구조에서는 Web 구현과 stub 구현이 같은 public 계약을 제공해야
  플랫폼별 import 차이를 앱 코드가 의식하지 않아도 된다.
- bytes-only export와 artifact export의 차이를 문서화하면 앱 개발자가 저장 UI에
  어떤 API를 써야 하는지 빠르게 판단할 수 있다.

## 검증

- `dart format`
- `flutter analyze`
- `flutter test`
- `(cd example && flutter test)`
- `git diff --check`
