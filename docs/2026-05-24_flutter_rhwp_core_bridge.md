# 2026-05-24 flutter_rhwp Core Bridge

## 작업한 내용

- `flutter_rhwp`를 method-channel 예제 구조에서 `flutter_rust_bridge` v2 기반 FFI/WASM 플러그인 구조로 전환했다.
- `rust/vendor/rhwp`에 upstream `edwardkim/rhwp` v0.7.12 소스를 포함해 빌드 중 GitHub fetch 없이 Rust 코어를 사용할 수 있게 했다.
- Rust facade에 `RhwpSession`을 두고 파일 열기, 페이지 수, 메타데이터, SVG 렌더링, 레이어 트리, 텍스트/Markdown 추출, HWP/HWPX/PDF/DOCX export, 편집 명령 적용을 Dart에서 호출할 수 있게 했다.
- Dart 공개 API로 `Rhwp`, `RhwpDocument`, `RhwpCommand`, `RhwpViewer`, `RhwpEditor`를 추가했다.
- Web/WASM 빌드에서 FRB와 vendored rhwp가 충돌하지 않도록 upstream vendored 코드의 WASM startup 및 web-sys canvas 스타일 호환 문제를 보정했다.

## 이 작업을 진행한 이유

- Flutter 앱에서는 모든 플랫폼에서 같은 Dart API로 HWP/HWPX 문서를 열고 다루는 것이 중요하다.
- rhwp의 핵심 파서와 렌더러는 Rust에 있으므로, Dart에서 직접 문서 포맷을 다시 구현하기보다 Rust 코어를 감싸는 방식이 유지보수에 유리하다.
- 수동 C ABI는 타입/메모리 관리 부담이 크므로 FRB opaque type을 사용해 세션 생명주기와 비동기 호출을 명확히 했다.
- `rust/vendor/rhwp`는 커밋 대상이다. 이 프로젝트 목표가 재현 가능한 플러그인 빌드이므로 upstream 소스 고정본이 필요하다. 반대로 `rust/target`은 빌드 산출물이므로 커밋하지 않는다.

## 이 작업을 통해 배울점

- Flutter Rust 플러그인은 Dart API를 bytes in/out 형태로 설계하면 플랫폼별 파일 시스템 제약과 엔진 로직을 분리할 수 있다.
- FRB Web/WASM은 단순히 Rust가 WASM으로 컴파일되는지만 보면 안 되고, browser isolation, generated `pkg/`, wasm-bindgen startup 같은 런타임 조건까지 같이 맞춰야 한다.
- vendoring은 저장소 크기를 늘리지만, 네트워크 없는 CI/로컬 빌드와 upstream 변경으로 인한 예기치 않은 실패를 줄여준다.
- DOCX/PDF 같은 변환 기능은 "API가 존재한다"와 "한컴/Word와 완전 동일한 결과를 보장한다"를 분리해 문서화해야 한다.

## 검증

- `cargo test --manifest-path rust/Cargo.toml`
- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
- `cd example && flutter build web`
- `cd example && flutter build macos --debug`
