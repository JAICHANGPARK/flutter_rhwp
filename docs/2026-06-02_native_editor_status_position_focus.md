# 2026-06-02 native editor status position focus

## 작업한 내용

- Flutter-native editor 상태바의 현재 위치 표시를 클릭하면 editor focus와 TextInput 연결을 복구하도록 연결했다.
- 상태바 위치 표시도 `Sec / Para / Offset`, `Cell`, `Object` 상태 텍스트 key를 유지하면서 클릭 가능한 editor chrome으로 바꿨다.
- 외부 입력 필드에 focus가 있는 상태에서 상태바 위치 표시를 누른 뒤 입력한 텍스트가 native editor의 `insertText` command로 들어가는 widget test를 추가했다.

## 이 작업을 진행한 이유

WebView fallback 없이 Flutter 위젯 에디터를 실제 편집기로 키우려면 status bar가 보기 전용 정보 영역에 머물면 안 된다. 문서 밖 UI로 focus가 빠진 뒤에도 현재 위치 표시를 누르면 곧바로 편집 위치로 돌아와 입력을 이어갈 수 있어야 데스크톱 에디터처럼 동작한다.

## 이 작업을 통해 배울점

- editor chrome 액션이 문서 내용을 바꾸지 않더라도 focus와 TextInput 연결을 복구하면 실제 입력 UX에 직접 영향을 준다.
- 상태바 텍스트를 clickable 위젯으로 바꿀 때는 기존 Text key를 유지해야 테스트와 앱 코드의 탐색 지점이 흔들리지 않는다.
- 외부 focus에서 editor focus로 돌아오는 흐름은 단순 focus flag보다 실제 입력 command 발생 여부로 검증하는 편이 더 강하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor status position restores editor focus"`
