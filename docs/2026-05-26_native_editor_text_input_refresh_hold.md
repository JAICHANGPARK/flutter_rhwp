# 2026-05-26 native editor text input refresh hold

## 작업한 내용

- `RhwpNativeEditor`의 텍스트 입력 커밋은 Rust 문서 명령으로 즉시 반영하되, 페이지 SVG refresh는 `TextInputAction.done` 또는 입력 연결 종료 이후에만 예약되도록 바꿨다.
- 입력 연결이 살아 있는 동안에는 `editRefreshDelay` 타이머를 시작하지 않는다. 입력이 끝나면 그때부터 기존 delay가 적용된다.
- 내부 편집 busy 상태와 툴바/status busy 표시를 분리해서, 짧은 텍스트 입력 명령 중에 툴바가 매 글자마다 비활성화되어 깜빡이지 않게 했다.
- 빠른 연속 입력이 이전 Rust 편집 명령 진행 중에 유실되지 않도록 텍스트 입력 커밋 큐를 추가했다.
- 본문 입력, 한글 IME 커밋, 표 셀 입력, pending text overlay 테스트 기대값을 새 refresh 정책에 맞게 갱신했다.

## 이 작업을 진행한 이유

기존 debounce는 마지막 입력 후 일정 시간이 지나면 active text input 상태에서도 페이지 SVG를 다시 렌더했다. 실제 예제 앱에서는 사용자가 스페이스를 누르거나 천천히 글자를 입력할 때마다 문서가 refresh 되는 것처럼 보일 수 있었다.

편집 명령과 화면 렌더를 분리하면 문서 데이터는 즉시 안전하게 갱신하면서도, 사용자가 아직 타이핑 중인 화면은 안정적으로 유지할 수 있다.

## 이 작업을 통해 배울 점

- 문서 편집기에서 "입력 커밋"과 "페이지 렌더 동기화"는 같은 타이밍일 필요가 없다.
- IME와 데스크톱 텍스트 입력은 사용자가 아직 편집 중인지 판단할 수 있는 신호를 제공하므로, refresh 타이밍을 입력 연결 종료나 action 기준으로 늦출 수 있다.
- Flutter-native 에디터는 Rust core 명령을 즉시 적용하되, 화면은 pending overlay와 명시적인 refresh 스케줄러로 안정화하는 구조가 필요하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --name "text input"`
