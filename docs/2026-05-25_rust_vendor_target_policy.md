# Rust Vendor Target Policy

## 작업한 내용

- README의 Rust 섹션에 `rust/vendor/rhwp`와 `rust/target`의 version control
  정책을 명시했다.
- CHANGELOG에 vendored source와 build output 처리 기준을 반영했다.
- 현재 저장소 상태를 확인해 `rust/vendor/rhwp`가 tracked source이고,
  `rust/.gitignore`가 `/target`을 ignore하고 있음을 확인했다.

## 이 작업을 진행한 이유

사용자가 `rust/target`은 ignore되는 것을 알겠지만 `vendor`도 커밋해야 하는지
질문했다. 이 프로젝트의 목표는 빌드 중 네트워크 fetch 없이 `edwardkim/rhwp`
v0.7.12 고정본으로 Flutter plugin을 재현 가능하게 빌드하는 것이다. 따라서
`rust/vendor/rhwp`는 소스 의존성으로 커밋되어야 한다.

반대로 `rust/target`은 Cargo가 생성하는 플랫폼/프로파일별 빌드 산출물이다. 크기가
크고 로컬 환경에 종속되며 재생성 가능하므로 커밋하면 안 된다.

## 이 작업을 통해 배울점

- vendored source와 build output은 모두 `rust/` 아래에 있어도 성격이 완전히 다르다.
- `rust/vendor/rhwp`는 `rust/Cargo.toml`의 local path dependency이므로 소스 계약에
  포함된다.
- `rust/target`은 Cargo cache/build artifact이므로 `.gitignore` 대상이다.
- 플러그인 사용자가 같은 결과를 재현해야 하는 경우에는 외부 Git fetch보다 고정된
  vendored source가 더 안정적이다.

## 검증

- `rust/.gitignore`에 `/target` ignore 규칙이 있음을 확인했다.
- `git ls-files rust/vendor/rhwp/Cargo.toml rust/vendor/rhwp/src/lib.rs`로 vendored
  rhwp 핵심 파일이 tracked 상태임을 확인했다.
- `git diff --check`
