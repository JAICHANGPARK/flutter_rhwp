# 2026-05-25 native editor select all

## 작업한 내용

- `RhwpNativeEditor`에 전체 선택 기능을 추가했다.
- 편집 리본의 선택 그룹, 컨텍스트 메뉴, Ctrl/Cmd+A 단축키가 같은 `_selectAllText()` 흐름을 사용하도록 연결했다.
- 전체 선택은 문서 변경 command를 만들지 않고 `pageLayerTreeModel()`의 text run source 위치를 읽어 `RhwpSelectionRange`만 갱신한다.
- widget test로 리본 버튼과 단축키가 전체 본문 범위를 선택하고 Rust edit/history command를 만들지 않는 것을 검증했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터가 WebView 에디터를 대체하려면 복사, 잘라내기, 서식 적용, 삭제 같은 기존 기능의 출발점이 되는 전체 선택 UX가 필요하다.
- 이미 page layer tree가 section/paragraph/offset을 제공하므로 JS DOM selection 없이 Flutter 상태만으로 전체 선택을 구현할 수 있다.
- 전체 선택을 문서 변경과 분리하면 undo/redo 이력과 편집 command 흐름을 오염시키지 않는다.

## 이 작업을 통해 배울점

- 선택 상태는 렌더링 좌표가 아니라 문서 source position을 기준으로 관리해야 복사/삭제/서식 command와 자연스럽게 이어진다.
- Flutter-native editor의 기본 단축키는 toolbar action과 같은 내부 함수를 공유해야 동작 차이가 줄어든다.
- table cell 내부 text run은 별도 편집 경로가 있으므로 현재 전체 선택은 본문 text run을 우선 대상으로 제한했다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor edit ribbon selects all body text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles select all shortcut"`
