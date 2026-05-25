# Pub Archive Ignore Policy

## 작업한 내용

- 루트 `.pubignore`를 추가해 `docs/` 작업 로그를 pub package archive에서 제외했다.
- `.pubignore`가 `.gitignore`보다 우선 적용되므로 build output, Flutter generated
  files, `rust/target` 제외 규칙도 함께 명시했다.
- CHANGELOG에 pub archive ignore 정책을 반영했다.
- `docs/날짜_작업명.md` 구조는 그대로 유지했다.

## 이 작업을 진행한 이유

사용자는 작업 단위 문서를 `docs/날짜_작업명.md` 형식으로 남기길 요청했다. 반면
`flutter pub publish --dry-run`은 top-level `docs` 디렉터리가 Pub package layout
convention과 맞지 않는다고 경고했다.

폴더명을 `doc`로 바꾸면 Pub convention에는 맞지만 사용자 요청과 기존 작업 로그 구조가
깨진다. 그래서 repository에는 `docs/`를 유지하고, runtime package archive에서는
작업 로그를 제외하도록 `.pubignore`를 사용했다. 단, `.pubignore`가 있으면 pub archive
생성 시 root `.gitignore`를 그대로 따라가지 않으므로 생성물 제외 규칙도 `.pubignore`에
명시했다.

## 이 작업을 통해 배울점

- repository documentation과 published package contents는 항상 같을 필요가 없다.
- 작업 로그처럼 개발 과정 기록은 repo에는 유용하지만, runtime package 사용자가 설치할
  archive에는 불필요할 수 있다.
- `.pubignore`를 사용하면 Git 추적 정책과 pub 배포 정책을 분리할 수 있다.
- `.pubignore`를 추가할 때는 `build/`, `.dart_tool/`, `rust/target/` 같은 생성물이
  archive에 들어가지 않는지도 같이 확인해야 한다.

## 검증

- `flutter pub publish --dry-run`
- `git diff --check`
