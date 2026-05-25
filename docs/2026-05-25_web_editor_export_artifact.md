# Web Editor Export Artifact

## 작업한 내용

- `RhwpWebEditorController.exportDocument()`를 추가했다.
- Web 구현과 non-Web stub 구현 모두 같은 메서드 시그니처를 제공하도록 맞췄다.
- example 앱의 Web editor mode export 흐름이 직접 bytes를 받은 뒤 파일명을 다시
  조립하지 않고, controller의 export artifact API를 쓰도록 정리했다.
- non-Web stub 테스트에 `exportDocument()` unsupported 예외 검증을 추가했다.
- README와 CHANGELOG에 Web editor export artifact 계약을 반영했다.

## 이 작업을 진행한 이유

직전 작업에서 Flutter bridge 문서 export는 `RhwpExportedDocument`로 bytes,
fileName, MIME type을 함께 반환하도록 정리했다. 하지만 Web editor mode는 여전히
`RhwpWebEditorController.export()`로 bytes만 받고 example 앱에서 파일명과 page
suffix를 다시 계산하고 있었다.

같은 저장/다운로드 흐름이 editor mode에 따라 다른 계약을 쓰면 앱 코드가 복잡해진다.
따라서 Web editor controller도 같은 artifact API를 제공하게 해서 Flutter bridge와
upstream Web editor mode가 동일한 저장 metadata 계약을 쓰도록 맞췄다.

## 이 작업을 통해 배울점

- 플랫폼별 구현 파일이 나뉘어 있어도 public controller API는 같은 모양을 유지해야
  example과 실제 앱 코드가 조건문 없이 단순해진다.
- Web editor가 내부적으로 iframe/JS editor를 호출하더라도 Flutter API 레벨에서는
  bridge 문서 export와 같은 결과 타입을 반환할 수 있다.
- unsupported platform stub에도 새 메서드를 추가하고 테스트해야 Web 외 플랫폼에서
  import나 호출 계약이 깨지지 않는다.
