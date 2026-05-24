# 2026-05-25 Android CI Integration

## 작업한 내용

- GitHub Actions mobile matrix의 Android job에 emulator 기반 integration workflow를 추가했다.
- Ubuntu runner에서 Android emulator를 사용할 수 있도록 KVM 권한 설정 단계를 추가했다.
- `reactivecircus/android-emulator-runner@v2`로 API 35 x86_64 emulator를 실행하고, `example/integration_test/asset_workflow_test.dart`를 `emulator-5554`에서 실행하도록 했다.
- README, CHANGELOG, 예제 asset workflow 문서에 Android integration test 범위를 반영했다.

## 이 작업을 진행한 이유

- 초기 목표의 Integration 항목은 Android에서도 example app의 파일 open/render/export 시나리오를 CI에서 확인하는 것이다.
- 기존 Android CI는 `flutter build apk --debug`까지만 확인해서, 실제 plugin registration, Android ABI별 Rust library loading, Dart API 호출까지는 검증하지 못했다.
- Android는 desktop과 다른 APK packaging 및 FFI library 배치 경로를 사용하므로, emulator에서 실제 workflow를 돌려야 회귀를 잡을 수 있다.

## 이 작업을 통해 배울점

- Flutter plugin은 APK 빌드 성공과 emulator 런타임 성공이 별개다. 특히 Rust FFI plugin은 ABI별 `.so` 배치가 실제 기기에서 확인되어야 한다.
- GitHub Actions Ubuntu runner에서 Android emulator를 안정적으로 쓰려면 KVM 접근 권한을 먼저 설정해야 한다.
- 같은 asset workflow를 desktop과 Android에 모두 붙이면, 파일 open/render/export API의 플랫폼 차이를 CI에서 빠르게 드러낼 수 있다.

## 검증

- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
- `git diff --check`
