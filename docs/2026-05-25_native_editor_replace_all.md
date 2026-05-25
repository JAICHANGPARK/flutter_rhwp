# 2026-05-25 native editor replace all

## 작업한 내용

- `RhwpNativeEditor` 도구 리본의 바꾸기 영역에 전체 바꾸기 버튼을 추가했다.
- 현재 검색 결과 전체를 하나의 `_runEdit()` transaction에서 `deleteText`와 `insertText` command로 치환하도록 연결했다.
- 같은 문단에서 여러 결과를 바꿀 때 offset이 밀리지 않도록 match를 뒤에서 앞으로 처리한다.
- widget test로 전체 바꾸기 command 순서, snapshot 저장, selection 갱신, 검색 결과 초기화를 검증했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터가 WebView 에디터를 대체하려면 현재 결과 하나만 바꾸는 흐름을 넘어 문서 단위 반복 편집도 지원해야 한다.
- 전체 바꾸기는 검색 결과가 이미 갖고 있는 section/paragraph/offset 위치를 이용하므로 JS 에디터 없이 Rust bridge command만으로 구현할 수 있다.
- 여러 command를 하나의 undo 단위로 묶어야 사용자가 전체 바꾸기를 한 번에 되돌릴 수 있다.

## 이 작업을 통해 배울점

- batch 편집은 앞에서부터 처리하면 같은 문단의 뒤쪽 offset이 변경될 수 있으므로 뒤에서 앞으로 적용하는 편이 안전하다.
- Flutter UI의 검색 상태는 문서 변경 상태와 다르므로 전체 바꾸기 후에는 기존 match cache를 명시적으로 비워야 한다.
- 여러 Rust command를 실행하더라도 사용자 관점의 하나의 편집이면 공통 edit transaction 경로에 태워야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor replaces all search matches"`
