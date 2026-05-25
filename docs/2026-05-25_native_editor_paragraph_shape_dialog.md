# 2026-05-25 native editor paragraph shape dialog

## 작업한 내용

- `RhwpCommand.applyParaFormat`와 `RhwpCommand.applyParaFormatRange`에 문단 정렬 외에도 줄간격, 줄간격 타입, 들여쓰기, 좌우 여백, 문단 앞/뒤 간격 값을 담을 수 있도록 Dart API를 확장했다.
- `RhwpNativeEditor`의 서식 리본에 문단 모양 버튼을 추가하고, Flutter 네이티브 다이얼로그에서 문단 모양 값을 입력해 Rust bridge 명령으로 적용하도록 연결했다.
- 보조 클릭 컨텍스트 메뉴에도 문단 모양 항목을 추가해서 툴바 없이도 같은 기능에 접근할 수 있게 했다.
- Dart command serialization 테스트, Flutter widget 테스트, Rust facade smoke 테스트에 문단 모양 속성 적용 시나리오를 추가했다.

## 이 작업을 진행한 이유

- 목표가 WebView 에디터 의존을 줄이고 100% Flutter 위젯 기반 에디터를 키우는 방향이므로, upstream rhwp 웹 에디터에 있는 서식 UI를 Flutter 네이티브 화면으로 단계적으로 옮겨야 한다.
- rhwp Rust 코어는 이미 문단 모양 JSON 속성을 받아 처리할 수 있으므로, 이번 작업은 코어를 새로 만들기보다 Flutter API와 UI를 코어 계약에 맞게 열어주는 작업이다.
- 사용자가 실제 문서를 편집할 때 정렬만으로는 부족하고, HWP 문서에서 자주 쓰는 줄간격과 문단 여백 조정이 필요하다.

## 이 작업을 통해 배울점

- Flutter 네이티브 에디터 포팅은 WebView 화면을 그대로 옮기는 작업이 아니라, Rust 문서 엔진의 명령 계약을 Flutter 위젯, 입력 상태, 선택 상태와 연결하는 작업이다.
- Rust 코어가 받을 수 있는 JSON 속성을 Dart command surface에서 명시적으로 열어두면 테스트 가능한 API가 되고, example/editor UI도 같은 경로를 재사용할 수 있다.
- 리본 버튼, 컨텍스트 메뉴, 단축키, 다이얼로그는 모두 최종적으로 같은 `RhwpDocument.apply*` 명령으로 합쳐져야 기능 중복과 플랫폼별 차이를 줄일 수 있다.

## 검증

- `RhwpCommand.applyParaFormat`와 `RhwpCommand.applyParaFormatRange`가 확장된 문단 속성을 JSON command envelope로 직렬화하는 테스트를 추가했다.
- `RhwpNativeEditor`에서 문단 모양 다이얼로그 값을 입력하면 선택된 문단 범위에 `applyParaFormatRange` 명령이 전달되는 widget 테스트를 추가했다.
- Rust facade smoke test에서 확장된 문단 모양 JSON을 실제 `apply_command` 경로로 통과시키도록 보강했다.
