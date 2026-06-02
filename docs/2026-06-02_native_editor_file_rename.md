# 2026-06-02 Native Editor File Rename

## 작업한 내용

- Flutter-native editor의 파일 리본에 문서 이름 변경 버튼을 추가했다.
- 현재 `metadata.fileName`을 기본값으로 채운 파일명 다이얼로그를 만들고, 적용 시 `setFileName` 명령을 호출하도록 연결했다.
- fake session이 파일명 상태를 보관하도록 확장해 `setFileName` 이후 export 기본 파일명이 바뀌는지 테스트했다.
- 파일 리본 rename 테스트에서 명령 envelope, 변경 콜백, snapshot 생성, 저장 파일명 반영을 함께 검증했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView 기반 full editor를 대체하려면 본문 편집뿐 아니라 파일 관리 표면도 Flutter 위젯 안에서 처리해야 한다.

기존 파일 리본은 열기, 문서 정보, 저장, PDF 내보내기를 제공했지만 문서 이름 변경은 UI에 없었다. rhwp core에는 이미 `setFileName` 명령이 있으므로 이를 Flutter-native 리본에 노출하면 저장/다운로드 기본 파일명을 앱 내부에서 바로 관리할 수 있다.

## 이 작업을 통해 배울점

- 파일명 변경은 문서 내용 편집과 다르지만 export metadata에 영향을 주므로 native editor의 파일 리본에서 다루는 것이 자연스럽다.
- `setFileName` 이후 `metadata()`가 바뀐 이름을 반환해야 `exportDocument`의 기본 파일명이 일관되게 바뀐다.
- 명령 UI를 추가할 때는 명령 호출만이 아니라 후속 저장 흐름에서 실제로 사용자에게 보이는 결과까지 테스트해야 한다.

## 검증

- `RhwpNativeEditor file ribbon renames document file` 테스트에서 `setFileName` 명령이 호출되고, 이후 HWP 저장 파일명이 새 이름으로 생성되는지 확인한다.
- 기존 파일 리본 export/open/document-info 테스트와 함께 실행해 파일 리본의 기존 동작과 충돌하지 않는지 확인한다.
