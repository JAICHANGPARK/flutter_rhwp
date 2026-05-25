# 2026-05-25 native editor search navigation shortcuts

## 작업한 내용

- `RhwpNativeEditor`에서 F3 단축키로 다음 검색 결과로 이동하도록 했다.
- Shift+F3은 이전 검색 결과로 이동하도록 연결했다.
- 이동은 기존 `_searchNext()`와 `_searchPrevious()`를 재사용해 selection, page 이동, highlight 상태가 버튼 동작과 동일하게 유지된다.
- widget test로 F3/Shift+F3이 검색 결과를 순회하고 문서 변경 command나 history command를 만들지 않는 것을 검증했다.

## 이 작업을 진행한 이유

- Ctrl/Cmd+F로 검색창에 접근한 뒤 결과 이동도 키보드로 가능해야 실제 문서 편집 흐름이 끊기지 않는다.
- 찾기 버튼과 단축키가 같은 내부 흐름을 공유하면 검색 결과 카운트, active highlight, selection 이동이 일관된다.
- 검색 결과 이동은 view/editor state 변경이므로 Rust 편집 command와 undo history에서 분리되어야 한다.

## 이 작업을 통해 배울점

- Flutter-native editor의 단축키는 기능별 command를 새로 만들기보다 기존 UI action을 호출하는 구조가 유지보수에 유리하다.
- 검색 결과 이동은 문서 source position으로 selection을 바꾸는 동작이므로 렌더링 overlay와 page navigation을 함께 갱신해야 한다.
- keyboard-first UX를 채우면 WebView full editor와의 실사용 격차가 줄어든다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor cycles search matches with F3 shortcuts"`
