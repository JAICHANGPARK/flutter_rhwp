# 2026-05-25 native editor search replace

## 작업한 내용

- `RhwpNativeEditor` 도구 리본에 바꾸기 입력창과 현재 검색 결과 바꾸기 버튼을 추가했다.
- 현재 선택된 검색 결과를 `deleteText`와 `insertText` Rust bridge command로 교체하도록 연결했다.
- 바꾸기 작업은 기존 `_runEdit()` 경로를 타도록 해서 snapshot 기반 undo/redo 이력에 포함되게 했다.
- widget test로 검색 결과를 바꿀 때 command 순서, snapshot 저장, selection 갱신, 검색 결과 카운트 갱신, 남은 검색 결과 offset 보정을 검증했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터가 upstream 웹 에디터를 대체하려면 찾기뿐 아니라 선택된 검색 결과를 바로 수정하는 기본 편집 흐름이 필요하다.
- 검색 결과는 page layer tree가 제공하는 section/paragraph/offset 위치를 갖고 있으므로, 별도 JS 에디터를 호출하지 않고도 Rust 문서 command로 안전하게 반영할 수 있다.
- 바꾸기 기능을 undo-aware edit path에 태우면 이후 replace all, 변경 추적, 저장 전 dirty state 같은 기능으로 확장하기 쉽다.

## 이 작업을 통해 배울점

- Flutter-native 편집 기능은 화면상의 SVG 위치보다 문서 source position을 기준으로 command를 만들어야 한다.
- 검색 결과를 문서 변경으로 바꿀 때는 기존 match list를 그대로 신뢰하기보다 변경된 항목을 제거하거나 재검색하는 상태 관리가 필요하다.
- replacement 길이가 기존 match 길이와 다르면 같은 문단의 뒤쪽 검색 결과 offset도 같이 보정해야 한다.
- undo/redo가 붙은 편집기는 작은 command도 공통 edit transaction 경로를 지나야 사용자 경험이 일관된다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor replaces the active search match"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor shifts remaining search matches after replace"`
