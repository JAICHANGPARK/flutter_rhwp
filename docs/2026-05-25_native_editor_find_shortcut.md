# 2026-05-25 native editor find shortcut

## 작업한 내용

- `RhwpNativeEditor`에서 Ctrl/Cmd+F 단축키를 처리하도록 추가했다.
- 단축키가 입력되면 도구 리본을 열고 Flutter-native 검색 입력창에 focus를 이동한다.
- 검색 입력창에 전용 `FocusNode`를 연결하고, toolbar state에 리본 탭을 전환하는 내부 메서드를 추가했다.
- widget test로 단축키 실행 후 검색 입력창이 표시되고 focus를 받으며 문서 변경 command가 발생하지 않는 것을 검증했다.

## 이 작업을 진행한 이유

- 찾기 UI가 있어도 키보드로 접근할 수 없으면 실제 문서 편집 흐름에서 사용성이 떨어진다.
- upstream 웹 에디터처럼 편집 중 바로 찾기를 호출하려면 Flutter-native 리본과 Focus 시스템을 연결해야 한다.
- 검색 focus는 문서 변경이 아니므로 undo/history command와 분리되어야 한다.

## 이 작업을 통해 배울점

- Flutter-native editor에서 리본 탭 상태와 문서 focus 상태는 별도로 관리하되, 단축키는 두 상태를 함께 전환해야 한다.
- TextInputClient 기반 에디터에서 검색창 focus로 이동하면 본문 입력 connection을 자연스럽게 닫아야 한다.
- toolbar 내부 상태를 외부 shortcut에서 제어할 때는 좁은 `GlobalKey` 메서드를 두는 방식이 현재 구조에서는 가장 작은 변경이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor focuses search with find shortcut"`
