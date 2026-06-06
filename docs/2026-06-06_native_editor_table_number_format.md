# Native editor table number format

## 작업한 내용

- `RhwpCommand.getTextInTableCell`과 `RhwpDocument.textInTableCell(...)`을 추가했다.
- Rust `RhwpCommand::GetTextInTableCell`을 `HwpDocument.get_text_in_cell_native(...)`에 연결했다.
- Flutter-native 표 리본에 숫자 서식 버튼 3개를 추가했다.
  - 1,000 단위 구분 토글
  - 소수 자릿수 증가
  - 소수 자릿수 감소
- 선택된 표 셀의 각 셀 문단을 읽고, 순수 숫자 텍스트일 때만 delete/insert 명령으로 치환하도록 구현했다.
- command serialization, document convenience API, widget ribbon 동작 테스트를 추가했다.
- `README.md`, `CHANGELOG.md`, `docs/API_SPEC.md`, `docs/TODO.md`, `docs/NATIVE_EDITOR_PARITY.md`를 갱신했다.

## 이 작업을 진행한 이유

upstream Web editor에는 표 메뉴의 `1,000 단위 구분`, `자릿점 넣기`, `자릿점 빼기`가 있다. Flutter-native editor가 WebView editor를 단계적으로 대체하려면 표 작성에서 자주 쓰는 숫자 서식 기능도 내장 리본과 Dart API 경로로 제공해야 한다.

이번 구현은 새 FRB 함수 추가가 아니라 기존 `applyCommand(commandJson)` envelope 확장이다. 그래서 generated bridge 재생성 없이 Rust command enum과 Dart command wrapper만 추가하면 된다.

## 이 작업을 통해 배울점

- Flutter-native editor 기능은 대부분 `RhwpEditorController`가 선택 context를 계산하고 `RhwpDocument`가 Rust command를 실행하는 구조로 쌓을 수 있다.
- 표 숫자 서식은 셀 속성 변경이 아니라 셀 문단 텍스트 치환 명령이다.
- 문서 훼손을 줄이려면 숫자와 문자가 섞인 셀은 자동 변경하지 않는 보수적인 규칙이 필요하다.
- `applyCommand` 내부 command만 확장하는 변경은 FRB codegen 재생성이 필요하지 않다.

## 검증

```sh
dart analyze
flutter test test/flutter_rhwp_test.dart --plain-name "table cell commands serialize to Rust envelopes"
flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor formats selected table cell numbers"
cargo check --manifest-path rust/Cargo.toml
```
