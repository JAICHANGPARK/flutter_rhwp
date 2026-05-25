# Export Artifact Metadata

## 작업한 내용

- `RhwpExportFormat`에 저장 확장자와 MIME type 메타데이터를 추가했다.
- `RhwpExportedDocument`를 추가해 export 결과를 `bytes`, `fileName`,
  `mimeType`, `format`으로 함께 다룰 수 있게 했다.
- `RhwpDocument.exportDocument()`를 추가해 Flutter bridge 문서 export가
  앱의 저장/다운로드 UI에서 바로 쓸 수 있는 결과 객체를 반환하게 했다.
- example 앱의 저장 흐름을 기존 `_ExportKind` 확장자 매핑 대신 공개 API의
  export metadata 계약을 사용하도록 바꿨다.
- 파일명 기본값, Windows/macOS/Linux 경로 stem 처리, page export suffix,
  MIME type 매핑을 Dart unit test로 검증했다.

## 이 작업을 진행한 이유

사용자가 기대하는 흐름은 HWP/HWPX를 열고, 수정하고, 다시 HWP/HWPX/PDF/DOCX
등으로 저장하거나 Web에서 다운로드하는 것이다. 이때 앱마다 확장자, MIME type,
기본 파일명 규칙을 따로 만들면 Flutter bridge, Web editor mode, example app의
동작이 쉽게 어긋난다.

그래서 export bytes만 반환하던 낮은 레벨 API는 유지하면서, 저장 UI에서 필요한
메타데이터를 포함한 상위 API를 추가했다. example 앱도 이 상위 API를 사용하게
해서 실제 사용자가 보는 저장/다운로드 흐름과 public Dart API의 계약이 같아졌다.

## 이 작업을 통해 배울점

- 파일 변환 API는 bytes만으로는 부족하다. 플랫폼 저장 UI와 브라우저 다운로드에는
  확장자, MIME type, 안정적인 기본 파일명이 함께 필요하다.
- example 앱에서만 쓰는 매핑은 쉽게 drift가 생긴다. 공개 API에 올릴 수 있는
  계약은 패키지 본문에 두고 example은 그 계약을 소비하는 편이 유지보수에 좋다.
- page 단위 export는 전체 문서 export와 파일명 규칙이 달라야 한다. 예를 들어
  `sample-page-1.svg`처럼 page suffix를 붙이면 여러 페이지를 저장할 때 덮어쓰기
  위험을 줄일 수 있다.
