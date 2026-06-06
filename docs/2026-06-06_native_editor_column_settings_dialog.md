# Native editor column settings dialog

## 작업한 내용

- Flutter-native Page 리본에 `Column settings` 버튼을 추가했다.
- dialog는 현재 section의 `document.columnDef(...)`를 읽어 단 수, 단 종류, 동일 너비, 단 간격을 초기값으로 보여준다.
- 사용자가 값을 바꾸고 Apply를 누르면 `document.setColumnDef(...)`를 호출한다.
- 1/2/3단 quick preset은 유지하고, 상세 설정은 같은 command-backed 경로를 공유한다.
- widget test로 dialog 초기값 로딩, 값 수정, `setColumnDef` command payload를 검증한다.

## 이 작업을 진행한 이유

1/2/3단 preset만으로는 upstream Web editor의 다단 설정을 대체하기 어렵다. 플러그인 사용자가 툴바 기능을 직접 구현할 때도 단 수와 종류, 간격을 명시적으로 제어할 API와 기본 UI가 필요하다.

## 이 작업을 통해 배울점

- Flutter-native editor의 dialog는 WebView UI를 호출하지 않고 `RhwpDocument` command API만 사용해야 한다.
- section 단위 명령은 dialog를 열 때 조회하고, 적용 시점에는 snapshot 기반 `_runEdit` 경로로 들어가야 undo/dirty 흐름과 맞는다.
- preset과 상세 설정이 같은 core command를 쓰면 테스트와 API 설명이 단순해진다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies section column settings dialog"
flutter analyze
```
