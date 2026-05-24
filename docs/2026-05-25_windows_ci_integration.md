# 2026-05-25 Windows CI Integration

## 작업한 내용

- GitHub Actions desktop matrix의 Windows job에 `flutter test integration_test/asset_workflow_test.dart -d windows` 단계를 추가했다.
- README, CHANGELOG, 예제 asset workflow 문서에 Windows desktop integration test 추가 내용을 반영했다.

## 이 작업을 진행한 이유

- 초기 목표의 Integration 항목은 desktop build뿐 아니라 example app의 파일 open/render/export 시나리오를 여러 플랫폼 CI에서 검증하는 것이다.
- Linux와 macOS는 실제 integration workflow가 CI에 들어갔지만, Windows는 `flutter build windows --debug`까지만 확인하고 있었다.
- Windows는 FFI dynamic library 배치, CMake/cargokit 산출물 위치, plugin registration 경로가 Linux/macOS와 다르므로 실제 Dart API 호출까지 확인해야 한다.

## 이 작업을 통해 배울점

- Flutter desktop plugin은 플랫폼별 빌드가 성공해도 런타임 plugin loading이 따로 깨질 수 있다.
- Windows runner는 headless display wrapper가 필요한 Linux와 달리 native desktop device로 integration test를 실행할 수 있다.
- CI matrix에 동일한 asset workflow를 붙이면, 같은 샘플 문서의 open/render/export 회귀를 플랫폼별로 비교하기 쉬워진다.

## 검증

- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
- `git diff --check`
