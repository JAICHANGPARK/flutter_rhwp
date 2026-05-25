# 2026-05-25 native editor tab input

## 작업한 내용

- `RhwpNativeEditor`에서 Tab 키 입력을 본문 탭 문자 삽입으로 연결했다.
- 일반 커서 상태에서는 현재 section/paragraph/offset에 `\t`를 삽입하고 커서를 한 칸 이동한다.
- 텍스트 선택이 있는 상태에서는 기존 선택 영역을 삭제한 뒤 같은 위치에 탭 문자를 삽입한다.
- 기존 `_insertCommittedText` 경로를 재사용해 table cell 입력, selection replacement, change callback, undo snapshot 흐름과 같은 규칙을 따르도록 했다.
- widget test로 일반 Tab 삽입과 선택 영역 대체 삽입을 검증했다.

## 이 작업을 진행한 이유

- 문서 편집기에서 Tab은 기본 입력 동작이므로 Flutter-native 에디터 포팅 범위에 포함되어야 한다.
- Focus traversal로 빠지는 대신 편집 surface가 직접 키 입력을 처리해야 WebView 없이도 문서 편집 경험을 유지할 수 있다.
- 새 Rust command를 만들지 않고 기존 insert/delete command 조합을 재사용하면 현재 브리지와 history 구조를 흔들지 않고 기능을 확장할 수 있다.

## 이 작업을 통해 배울점

- Flutter 키보드 이벤트는 Focus 레벨에서 먼저 잡아야 텍스트 편집기 내부 입력으로 안정적으로 처리할 수 있다.
- 선택 영역이 있는 입력은 “삭제 후 삽입” 규칙을 공유해야 일반 문자, 붙여넣기, Tab 입력이 같은 방식으로 동작한다.
- 작은 입력 기능도 command 기록과 change callback 검증을 함께 두어야 이후 undo/redo 동작을 안전하게 확장할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts tab from keyboard"`
