# 2026-05-24 Release Metadata And Documentation

## 작업한 내용

- 패키지 버전을 `2026.5.24`로 맞췄다.
- `pubspec.yaml`, iOS/macOS podspec, `rust/Cargo.toml`, `rust/Cargo.lock`, `example/pubspec.lock`, `CHANGELOG.md`의 버전 표기를 정리했다.
- 저장소 링크를 `JAICHANGPARK/flutter_rhwp`로 맞추고, upstream `edwardkim/rhwp`는 README에서 Rust core 출처로 명시했다.
- README에 현재 구현 범위, Web/WASM 빌드 방법, upstream `@rhwp/editor` Web editor embed 사용법, 검증 명령을 추가했다.
- 작업 단위 문서를 `docs/2026-05-24_*.md` 형식으로 추가했다.

## 이 작업을 진행한 이유

- Flutter package, CocoaPods, Rust crate 버전이 다르면 릴리스와 예제 lockfile에서 어떤 코드가 배포 대상인지 혼란이 생긴다.
- 이 저장소는 `JAICHANGPARK/flutter_rhwp`가 주 저장소이고, `edwardkim/rhwp`는 코어 엔진 upstream이므로 README에서 역할을 분리해 설명해야 한다.
- 큰 구조 변경은 커밋 메시지만으로 의도를 파악하기 어렵기 때문에, 작업별 배경과 배울점을 문서로 남겨 후속 작업자가 빠르게 따라올 수 있게 했다.

## 이 작업을 통해 배울점

- 플러그인 전환 작업은 코드 변경뿐 아니라 pubspec, podspec, lockfile, README, changelog가 같이 움직여야 한다.
- vendored dependency를 커밋할 때는 "왜 vendoring하는지"와 "무엇을 ignore해야 하는지"를 문서화해야 리뷰 부담이 줄어든다.
- 날짜 기반 문서는 릴리스 히스토리와 개발 의사결정 기록을 연결하는 가벼운 ADR 역할을 할 수 있다.

## 검증

- `rg`로 버전 표기가 `2026.5.24`로 맞는지 확인했다.
- `git diff --check`
- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
