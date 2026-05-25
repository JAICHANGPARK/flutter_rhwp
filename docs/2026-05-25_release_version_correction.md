# 2026-05-25 release version correction

## 작업한 내용

- `pubspec.yaml`, Rust `Cargo.toml`, `Cargo.lock`, iOS/macOS podspec, example Podfile lock의 패키지 버전 표기를 `2026.5.24`로 맞췄다.
- README와 CHANGELOG의 릴리스 버전 표기도 `2026.5.24`로 맞췄다.

## 이 작업을 진행한 이유

플러그인 릴리스 버전은 사용자가 요청한 `2026.5.24`로 고정되어야 한다. Dart, Rust, CocoaPods 메타데이터가 서로 다르면 배포 전 검증이나 예제 앱 의존성 해석에서 혼동이 생길 수 있으므로 한 번에 정리했다.

## 배울점

- Flutter FFI 플러그인은 Dart `pubspec.yaml`뿐 아니라 Rust crate와 iOS/macOS podspec에도 버전이 남는다.
- example의 Podfile lock도 로컬 플러그인 pod 버전을 기록하므로, 버전 정정 시 함께 확인해야 한다.

## 검증

- `rg -n "2026\\.5\\.25|2026\\.5\\.24" . --glob '!rust/target/**' --glob '!example/build/**' --glob '!build/**'`
