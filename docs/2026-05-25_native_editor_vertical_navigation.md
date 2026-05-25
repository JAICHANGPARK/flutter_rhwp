# 2026-05-25 native editor vertical navigation

## 작업한 내용

- `RhwpNativeEditor`에서 ArrowUp/ArrowDown 키로 이전/다음 본문 문단으로 커서를 이동하도록 했다.
- 이동 대상 문단은 page layer tree의 body text run을 section/paragraph 순서로 모아 계산한다.
- 이동할 때 기존 offset을 최대한 유지하고, 대상 문단 길이보다 큰 경우 문단 끝으로 보정한다.
- Shift+ArrowUp/ArrowDown 조합은 selection anchor를 유지한 채 문단 이동 방향으로 선택을 확장한다.
- widget test로 일반 이동, Shift 선택 확장, 편집 command가 발생하지 않는 동작을 검증했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터를 실제 문서 편집기로 포팅하려면 좌우 이동뿐 아니라 문단 간 세로 이동이 필요하다.
- 현재 렌더링 layer tree가 source position을 제공하므로 DOM/WebView 없이도 Flutter 위젯 레벨에서 문서 navigation을 구현할 수 있다.
- 방향키 이동은 문서를 수정하는 작업이 아니므로 Rust 편집 command와 undo/redo history에서 분리되어야 한다.

## 이 작업을 통해 배울점

- 세로 navigation은 화면 좌표만으로 처리하기보다 section/paragraph/offset 기준의 문서 위치 모델을 먼저 안정화해야 한다.
- 선택 확장은 새 커서 위치만 바꾸는 것이 아니라 기존 selection start를 anchor로 보존해야 한다.
- page layer tree를 기반으로 한 작은 단위의 키보드 기능을 쌓아가면 WebView 에디터 의존도를 단계적으로 줄일 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles keyboard navigation and delete"`
