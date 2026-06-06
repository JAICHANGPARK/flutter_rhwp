# Flutter Rust Bridge 2.12 update

## 작업한 내용

- `flutter_rust_bridge` Dart dependency를 `2.12.0`으로 갱신했다.
- Rust facade crate의 `flutter_rust_bridge` dependency를 `=2.12.0`으로 갱신했다.
- `flutter_rust_bridge_codegen` 갱신 결과로 생성된 Dart/Rust bridge 파일을 반영했다.
- `THIRD_PARTY_NOTICES.md`의 bridge 버전 표기를 `2.12.0`으로 맞췄다.
- example lockfile의 local package version을 오늘 릴리스 버전에 맞춰 갱신했다.
- Rust crate와 iOS/macOS podspec 버전도 `2026.6.6`으로 맞춘다.

## 이 작업을 진행한 이유

이 플러그인은 Dart API와 Rust rhwp core 사이를 `flutter_rust_bridge`로 연결한다. codegen 버전이 바뀌면 생성 파일도 함께 갱신되어야 하고, 런타임 dependency와 generated binding이 같은 계열로 맞아야 한다.

사용자가 `flutter_rust_bridge_codegen`을 최신화했기 때문에 이번 작업에서는 이 변경을 되돌리지 않고, full editor dirty bridge 작업과 같은 검증 흐름 안에서 보존했다.

## 이 작업을 통해 배울점

- FRB generated file은 수동 수정 대상이 아니라 codegen 산출물이다.
- codegen 업데이트는 Dart dependency, Rust dependency, generated Dart 파일, generated Rust 파일, third-party notice가 함께 움직여야 한다.
- bridge 버전 변경은 기능 코드가 작아 보여도 분석, 테스트, cargo 검증을 같이 실행해야 한다.

## 검증

```sh
flutter analyze
cd rust && cargo check
```
