# 2026-05-26 Native Editor Alt L Character Shape

## 작업한 내용

- Flutter-native 에디터의 키 처리에 `Alt+L` 글자 모양 단축키를 추가했다.
- 영문 `L/l`뿐 아니라 한글 자판 입력에서 들어올 수 있는 `ㄹ` 문자도 같은 단축키로 처리했다.
- `Ctrl/Cmd+L` 문단 왼쪽 정렬과 충돌하지 않도록 Alt 단독 조합에서만 글자 모양 다이얼로그를 연다.
- 단축키로 글자 모양 다이얼로그가 열리는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream rhwp web editor는 `Alt+L`로 글자 모양 대화상자를 연다. Flutter-native 에디터가 WebView 에디터를 대체하려면 메뉴 버튼뿐 아니라 기존 사용자가 기대하는 편집 단축키도 Flutter 키 이벤트로 직접 처리해야 한다.

## 이 작업을 통해 배울점

- 같은 `L` 키라도 `Ctrl/Cmd+L`은 문단 정렬, `Alt+L`은 글자 모양처럼 조합 키별 의미가 다르므로 키 처리 우선순위가 중요하다.
- Flutter 키 이벤트에서는 logical key와 character를 함께 확인하면 영문/한글 자판 차이를 더 견고하게 처리할 수 있다.
- 단축키는 문서 변경 명령을 즉시 실행하지 않는 UI 진입 기능이므로, 테스트에서는 다이얼로그 표시와 명령 미발행을 함께 확인하는 편이 안전하다.

## 검증

- `dart format`
- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`

Flutter widget test 실행은 sandbox에서 localhost test server socket 생성이 막혀 실패할 수 있다.
