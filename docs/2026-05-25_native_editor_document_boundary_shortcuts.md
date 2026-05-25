# 2026-05-25 native editor document boundary shortcuts

## 작업한 내용

- `RhwpNativeEditor`에서 Ctrl/Cmd+Home 단축키로 문서 본문 시작 위치로 이동하도록 했다.
- Ctrl/Cmd+End는 문서 본문 끝 위치로 이동하도록 연결했다.
- Shift 조합을 함께 누르면 현재 selection anchor를 유지한 채 문서 시작/끝까지 선택을 확장한다.
- 문서 경계는 모든 page layer tree의 body text run source position을 스캔해서 계산한다.
- widget test로 multi-page 문서에서 이동, page 갱신, selection 확장, command/history 미발생을 검증했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터가 실제 문서 편집기처럼 동작하려면 문단 단위 Home/End뿐 아니라 문서 경계 이동도 필요하다.
- 이미 page layer tree가 section/paragraph/offset을 제공하므로 렌더링 좌표가 아니라 문서 source position 기준으로 안정적으로 이동할 수 있다.
- 이동과 선택 확장은 편집 command가 아니므로 undo/redo history와 분리되어야 한다.

## 이 작업을 통해 배울점

- 문서 전체 navigation은 현재 page만 보면 안 되고 모든 page layer tree를 대상으로 source position의 최소/최대 값을 계산해야 한다.
- Ctrl/Cmd 조합과 Shift 조합은 같은 boundary 계산을 공유하되 selection 적용 방식만 달라야 한다.
- multi-page 테스트에는 page별 paragraph source를 다르게 만든 fixture가 필요하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles document boundary shortcuts"`
