# 2026-05-25 Apple CocoaPods Rust Linkage

## 작업한 내용

- `ios/flutter_rhwp/Package.swift`와 `macos/flutter_rhwp/Package.swift`를 제거해 `flutter_rhwp`가 Apple에서 CocoaPods podspec 경로를 사용하도록 했다.
- 예제 iOS/macOS 프로젝트에 CocoaPods `Podfile`, `Podfile.lock`, Pods workspace 연결, Pods xcconfig include를 생성했다.
- `Rhwp.ensureInitialized()`는 iOS/macOS에서 FRB `ExternalLibrary.process()`를 기본 loader로 사용하도록 유지했다. CocoaPods/cargokit이 Rust static library를 앱에 링크하므로 현재 프로세스 symbol lookup이 맞다.
- README와 CHANGELOG에 Apple은 현재 CocoaPods/cargokit 경로를 사용하며 SwiftPM manifest는 Rust build/linkage가 준비될 때 다시 추가해야 한다고 정리했다.

## 이 작업을 진행한 이유

- macOS integration test에서 `frb_get_rust_content_hash` symbol을 찾지 못했다. 원인은 SwiftPM package가 Swift wrapper만 포함하고 Rust archive를 빌드/링크하지 않았기 때문이다.
- 저장소에는 이미 podspec과 cargokit 설정이 있어서 Rust static library를 빌드하고 `-force_load`로 링크하는 경로가 준비되어 있었다.
- 목표 플랫폼에 iOS/macOS가 포함되어 있으므로, 현재 동작하는 Apple packaging 경로를 명확히 선택하고 검증하는 편이 SwiftPM manifest를 남겨 실패하는 것보다 낫다.

## 이 작업을 통해 배울점

- Apple에서 FRB Rust 코어를 static library로 링크하면 Dart FFI loader는 dynamic framework를 여는 대신 `DynamicLibrary.process()`를 통해 현재 프로세스의 symbols를 조회해야 한다.
- SwiftPM manifest가 존재하면 Flutter 3.44는 해당 plugin을 SwiftPM compatible로 판단해 CocoaPods Rust build script를 우회할 수 있다.
- SwiftPM support를 제공하려면 Swift target만 선언하는 것으로는 부족하고, Rust archive를 빌드하거나 binary target으로 제공하는 경로까지 포함해야 한다.

## 검증

- `cd example && flutter test integration_test/asset_workflow_test.dart -d macos`
- `cd example && flutter build ios --debug --no-codesign`
- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
- `git diff --check`
