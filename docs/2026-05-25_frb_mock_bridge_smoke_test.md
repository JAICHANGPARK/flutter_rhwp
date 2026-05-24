# 2026-05-25 FRB Mock Bridge Smoke Test

## 작업한 내용

- `test/flutter_rhwp_test.dart`에 생성된 `RustLib` entrypoint를 mock mode로 초기화하는 smoke test를 추가했다.
- 테스트에서 `rust.rhwpVersion()` 호출이 `RustLib.instance.api`를 통해 mock Rust API로 전달되는지 확인한다.
- README의 CI 설명과 CHANGELOG에 FRB generated bridge smoke test 범위를 반영했다.

## 이 작업을 진행한 이유

- 초기 Test Plan에는 Dart 공개 API unit test와 FRB generated bridge smoke test가 모두 필요하다고 정리했다.
- 기존 단위 테스트는 `RhwpDocument.fromSession()`에 fake session을 주입해 공개 API 동작을 검증했지만, 생성된 FRB entrypoint가 Dart API 호출을 Rust API surface로 라우팅하는지는 직접 확인하지 않았다.
- 실제 FFI library를 로드하는 테스트는 플랫폼 integration test에 맡기고, unit test에서는 `RustLib.initMock`으로 codegen entrypoint 회귀를 빠르게 잡는 편이 안정적이다.

## 이 작업을 통해 배울점

- FRB codegen 파일은 직접 수정하지 않더라도 공개 API와 생성 API 사이의 호출 계약이 깨질 수 있다.
- `RustLib.initMock`을 쓰면 native library 없이도 Dart 쪽 generated bridge path를 검증할 수 있다.
- 실제 Rust library loading 검증과 Dart generated bridge routing 검증은 성격이 다르므로 테스트 계층을 분리하는 것이 좋다.

## 검증

- `dart format test/flutter_rhwp_test.dart`
- `flutter test`
- `git diff --check`
