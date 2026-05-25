# 2026-05-25 native editor file open callback

## 작업한 내용

- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`에 `onOpenRequested` 콜백을 추가했다.
- Flutter-native 에디터의 파일 리본 `Open` 버튼을 활성화하고, 콜백이 없을 때는 비활성 상태를 유지하게 했다.
- `Ctrl/Cmd+O` 단축키도 같은 open callback 경로를 호출하도록 연결했다.
- example 앱의 native editor 모드에서 파일 리본 `Open`은 기존 `file_picker` 열기 흐름을 호출하고, 파일 리본 export는 기존 저장 흐름을 재사용하도록 연결했다.
- widget test에서 파일 리본 open이 편집 command를 만들지 않고 앱 콜백만 호출하는지 검증했다.

## 이 작업을 진행한 이유

- upstream 웹 에디터는 자체 파일 메뉴에서 열기/저장을 처리한다. Flutter-native 에디터도 파일 리본이 실제 앱 워크플로우와 연결되어야 WebView 의존을 줄일 수 있다.
- 파일 선택은 플랫폼별 권한, sandbox, Web download 정책이 다르므로 에디터 위젯 내부가 아니라 앱 레벨 콜백으로 위임하는 구조가 맞다.
- example 앱에서 상단 앱바와 native editor 파일 리본이 같은 열기/저장 코드를 쓰면 사용자가 어느 UI를 눌러도 같은 결과를 얻는다.

## 이 작업을 통해 배울점

- 파일 열기는 문서 편집 command가 아니라 앱 shell 이벤트이므로 Rust command history와 분리해야 한다.
- Flutter 위젯 에디터는 문서 engine을 소유하기보다 앱이 넘겨준 `RhwpDocument`와 콜백을 조합하는 surface로 두는 것이 플랫폼 대응에 유리하다.
- 파일 메뉴 기능은 버튼을 보이게 하는 것만으로 끝나지 않고, 비활성 조건, busy 상태, 에러 표시, 예제 앱 연결까지 같이 검증해야 한다.

## 검증

- `RhwpNativeEditor` 파일 리본 `Open` 버튼이 `onOpenRequested`를 한 번 호출하는 widget test를 추가했다.
- open 동작이 `applyCommand`를 호출하지 않는 것을 확인했다.
- example 앱 native editor 모드에서 리본 open/export가 기존 file picker/save 흐름과 같은 콜백을 사용하도록 연결했다.
