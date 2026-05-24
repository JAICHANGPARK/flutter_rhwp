# 2026-05-24 CI Platform Verification

## 작업한 내용

- `.github/workflows/ci.yml`을 추가했다.
- CI를 `checks`, `web`, `desktop`, `mobile` 네 가지 job으로 나눴다.
- `checks` job은 Rust facade 테스트, Flutter pub get, analyze, 루트 테스트, 예제 테스트를 실행한다.
- `web` job은 clean clone에서 `flutter_rust_bridge_codegen build-web`로 `example/web/pkg`를 생성한 뒤 `flutter build web`을 실행한다.
- `desktop` job은 Linux, macOS, Windows 예제 앱 debug build를 matrix로 검증한다.
- `mobile` job은 Android debug APK와 iOS debug no-codesign build를 검증한다.

## 이 작업을 진행한 이유

- 목표의 Integration 항목에는 Android, iOS, macOS, Windows, Linux, Web에서 예제 앱 빌드와 파일 open/render/export 시나리오를 CI에 넣는 요구가 있다.
- 로컬에서는 `example/web/pkg`가 남아 있으면 Web build가 통과할 수 있지만, clean clone CI에서는 반드시 FRB WASM bundle 생성 단계가 필요하다.
- 플랫폼별 Cargokit/Rust toolchain 문제는 단위 테스트만으로 잡히지 않으므로 실제 `flutter build`를 matrix로 돌려야 한다.

## 이 작업을 통해 배울점

- FRB Web은 Flutter build 전에 Rust WASM artifact를 먼저 만들어야 하며, 이 산출물은 커밋하지 않고 CI에서 재생성하는 편이 안전하다.
- Android/iOS는 Rust cross target을 명시적으로 설치해야 Cargokit이 네이티브 라이브러리를 만들 수 있다.
- Desktop build는 각 runner의 시스템 의존성이 다르므로 Linux는 GTK/CMake/Ninja 계열 패키지를 명시적으로 설치해야 한다.
- CI는 기능 완성을 증명하는 수단이 아니라, 현재 지원한다고 주장하는 플랫폼 범위를 계속 검증하는 안전장치다.

## 검증

- 로컬에서 `flutter analyze`, `flutter test`, `cd example && flutter test`, `cd example && flutter build web`, `cd example && flutter build macos --debug`가 통과한 상태에서 CI를 추가했다.
- 실제 GitHub Actions 결과는 push 이후 원격에서 확인한다.
