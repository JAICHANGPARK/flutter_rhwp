# 2026-05-25 Web Widget CI

## 작업한 내용

- GitHub Actions의 `web` job에 `example` Web widget test 실행 단계를 추가했다.
- `flutter test --platform chrome test/widget_test.dart`를 FRB WASM build 전에 실행하도록 했다.
- README의 CI 설명과 CHANGELOG에 Web widget CI 범위를 반영했다.

## 이 작업을 진행한 이유

- Web example은 upstream Web editor mode와 Flutter bridge mode를 함께 제공한다.
- Web 기본 mode를 upstream editor로 바꾼 뒤에는 브라우저 환경에서 mode toggle shell이 실제로 렌더링되는지 CI에서 확인해야 한다.
- 이 검증은 FRB WASM bundle 생성보다 빠르고, WebAssembly build 문제가 생기기 전에도 Flutter Web UI 회귀를 분리해서 확인할 수 있다.

## 이 작업을 통해 배울점

- Web UI 회귀와 WASM build 회귀는 실패 원인이 다르므로 CI 단계도 분리하는 편이 디버깅하기 쉽다.
- Flutter Web widget test는 `kIsWeb` 분기를 실제 브라우저 target에서 확인할 수 있어, VM widget test만으로는 잡을 수 없는 Web-only UI 상태를 검증할 수 있다.
- plugin example은 빌드 성공뿐 아니라 사용자가 보는 기본 shell도 CI에서 확인해야 Web runtime 문제를 빨리 발견할 수 있다.

## 검증

- `cd example && flutter test --platform chrome test/widget_test.dart`
- `git diff --check`
