# 2026-05-25 macOS CI Integration

## 작업한 내용

- GitHub Actions desktop matrix의 macOS job에 `flutter test integration_test/asset_workflow_test.dart -d macos` 단계를 추가했다.
- Linux는 Xvfb가 필요하므로 기존처럼 `xvfb-run`을 사용하고, macOS는 native desktop device로 직접 실행하도록 분리했다.
- CHANGELOG와 예제 workflow 문서에 macOS CI integration test 추가 내용을 반영했다.

## 이 작업을 진행한 이유

- 목표의 Integration 항목은 여러 플랫폼에서 example app 빌드와 파일 open/render/export 시나리오를 CI에 넣는 것이다.
- Linux integration workflow는 이미 들어갔지만, macOS는 로컬 검증만 있고 CI에는 아직 반영되지 않았다.
- Apple CocoaPods/cargokit 경로가 macOS에서 실제 Rust symbols를 링크하는지 CI에서도 계속 확인해야 한다.
- macOS에서 `integration_test` 디렉터리 전체를 한 번에 실행하면 앱 재기동 과정에서 debug connection이 끊길 수 있어, 실제 asset open/render/export 시나리오를 담은 단일 workflow test를 CI 대상으로 삼았다.

## 이 작업을 통해 배울점

- 같은 Flutter desktop integration test라도 Linux와 macOS runner 환경이 다르다. Linux는 가상 display가 필요하지만 macOS는 Flutter macOS desktop device로 직접 실행할 수 있다.
- Apple packaging 변경은 빌드 성공만으로 충분하지 않고, 실제 Dart FFI 호출까지 통과하는 integration test가 있어야 회귀를 잡을 수 있다.
- CI matrix에서는 플랫폼별 실행 명령을 명확히 분리하는 편이 실패 원인을 빠르게 좁힌다.

## 검증

- `cd example && flutter test integration_test/asset_workflow_test.dart -d macos`
- `flutter analyze`
- `git diff --check`
