# 2026-05-25 iOS Simulator CI Integration

## 작업한 내용

- `tool/ci_run_ios_integration.sh`를 추가했다.
- 스크립트가 GitHub Actions macOS runner에서 사용 가능한 iPhone simulator를 찾아 boot하고, `example/integration_test/asset_workflow_test.dart`를 해당 simulator에서 실행하도록 했다.
- GitHub Actions `mobile` job의 iOS matrix에 iOS simulator integration workflow 단계를 추가했다.
- README와 CHANGELOG에 iOS simulator integration test 범위를 반영했다.

## 이 작업을 진행한 이유

- 목표의 Integration 항목은 iOS에서도 example app의 파일 open/render/export 시나리오를 CI에서 확인하는 것이다.
- 기존 iOS CI는 `flutter build ios --debug --no-codesign`까지만 확인해서, 실제 simulator 앱 실행, CocoaPods/cargokit Rust static library linkage, FRB 호출까지는 검증하지 못했다.
- macOS와 iOS는 같은 Apple 계열이어도 runner target, simulator runtime, library linkage 경로가 다르므로 iOS simulator에서 별도 workflow를 돌려야 한다.

## 이 작업을 통해 배울점

- iOS plugin은 build 성공과 simulator runtime 성공을 분리해서 봐야 한다. Rust static library가 앱에 링크되어도 simulator에서 FRB symbol lookup이 실제로 통과하는지 확인해야 한다.
- GitHub Actions macOS runner의 simulator 이름은 Xcode 이미지에 따라 달라질 수 있으므로, 고정 이름 대신 사용 가능한 iPhone simulator를 동적으로 선택하는 스크립트가 더 견고하다.
- 로컬 샌드박스에서 CoreSimulator 접근이 막히는 환경이 있을 수 있다. 이런 경우에는 스크립트 문법과 공통 테스트를 로컬에서 확인하고, 실제 simulator 실행은 CI에서 검증하도록 분리한다.

## 검증

- `bash -n tool/ci_run_ios_integration.sh`
- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
- `git diff --check`

로컬 Codex 샌드박스에서는 `xcrun simctl`이 CoreSimulatorService에 연결하지 못해 iOS simulator runtime 실행은 직접 확인하지 못했다.
