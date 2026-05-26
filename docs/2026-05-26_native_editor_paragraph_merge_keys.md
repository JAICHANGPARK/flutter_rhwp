# 2026-05-26 Native Editor Paragraph Merge Keys

## 작업한 내용

- `RhwpNativeEditor`에서 문단 시작 위치에서 Backspace를 누르면 이전 본문 문단 끝과 현재 문단 시작 사이를 `deleteRange`로 삭제해 문단을 병합하도록 했다.
- 문단 끝 위치에서 Delete를 누르면 현재 문단 끝과 다음 문단 시작 사이를 `deleteRange`로 삭제해 다음 문단과 병합하도록 했다.
- 첫 문단 시작 또는 마지막 문단 끝처럼 병합 대상이 없는 경계에서는 command와 page refresh를 실행하지 않도록 했다.
- page layer tree의 본문 문단 목록과 문단 끝 offset을 사용해 병합 대상 문단을 찾도록 연결했다.
- Backspace/Delete 문단 경계 병합 widget test를 추가했다.

## 이 작업을 진행한 이유

upstream web editor는 문단 시작에서 Backspace를 누르면 이전 문단과 병합하는 기본 편집 흐름을 갖고 있다. Flutter-native editor도 WebView fallback을 줄이려면 글자 삭제뿐 아니라 문단 경계에서의 키보드 편집 동작까지 문서 편집기처럼 동작해야 한다.

기존 native editor는 문단 시작에서 Backspace가 사실상 no-op에 가까웠고, 문단 끝 Delete도 단일 문자 삭제 command로만 흐를 수 있었다. 실제 편집에서는 두 문단을 붙이는 동작이 자주 쓰이므로 Rust core의 `deleteRange` command를 재사용해 Flutter 위젯 경로에 붙였다.

## 이 작업을 통해 배울점

- 문단 경계 편집은 단일 문자 삭제와 다르게 page layer tree에서 이전/다음 문단의 구조 정보를 읽어야 한다.
- Flutter-native editor는 DOM 이벤트를 그대로 옮기는 대신, `RhwpDocument` command와 overlay state를 기준으로 같은 편집 의도를 재구성하는 방식이 맞다.
- Backspace/Delete 같은 기본 키도 문맥에 따라 글자 삭제, 선택 삭제, 표 셀 삭제, 문단 병합으로 분기되어야 실제 에디터 UX에 가까워진다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter test test/rhwp_widget_test.dart --name "RhwpNativeEditor merges paragraphs at keyboard boundaries"`는 현재 sandbox에서 localhost test server socket 생성 권한이 없어 실행이 차단된다.
