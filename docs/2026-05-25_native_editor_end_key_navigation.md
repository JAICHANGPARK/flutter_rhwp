# 2026-05-25 native editor end key navigation

## 작업한 내용

- `RhwpNativeEditor`에서 End 키를 처리해 현재 문단 끝으로 caret을 이동하도록 했다.
- Shift+End는 기존 선택 anchor를 유지하면서 현재 문단 끝까지 selection을 확장한다.
- 문단 끝 위치는 `pageLayerTreeModel()`의 body text run source range 중 같은 section/paragraph의 가장 큰 `charEnd`로 계산한다.
- widget test로 End/Shift+End가 문서 변경 command 없이 cursor/selection만 갱신하는지 검증했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터가 실제 문서 편집기로 동작하려면 좌우 이동뿐 아니라 줄/문단 경계 이동 같은 기본 키보드 탐색이 필요하다.
- Home 키는 이미 문단 시작 이동을 담당하고 있었으므로, End 키를 추가해 키보드 선택 UX의 균형을 맞췄다.
- source position 기반으로 이동해야 이후 삭제, 복사, 서식 적용 command와 같은 선택 모델을 그대로 공유할 수 있다.

## 이 작업을 통해 배울점

- caret 이동도 화면 좌표가 아니라 page layer tree의 section/paragraph/offset을 기준으로 계산해야 편집 command와 일관된다.
- 문서 변경이 없는 navigation은 undo/history command를 만들면 안 된다.
- async page layer tree 조회를 키 이벤트에서 사용할 때는 `unawaited`로 호출하되, 완료 시점에 mounted 상태를 확인해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles keyboard navigation and delete"`
