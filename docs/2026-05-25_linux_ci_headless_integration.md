# 2026-05-25 Linux CI Headless Integration

## 작업한 내용

- GitHub Actions Linux desktop job의 system dependency에 `xvfb`를 추가했다.
- 예제 integration workflow 실행 명령을 `flutter test integration_test -d linux`에서 `xvfb-run -a flutter test integration_test -d linux`로 변경했다.
- CHANGELOG와 기존 예제 workflow 문서에 Linux desktop integration test가 headless runner에서 Xvfb로 실행된다는 내용을 반영했다.

## 이 작업을 진행한 이유

- Linux desktop integration test는 실제 Flutter desktop app을 실행하므로 display server가 필요하다.
- GitHub Actions `ubuntu-latest` runner는 기본적으로 GUI display가 없어서, 테스트 명령만 추가하면 CI에서 실패할 수 있다.
- 목표의 Integration 항목은 Linux 예제 앱 빌드뿐 아니라 파일 open/render/export workflow 검증까지 포함하므로, CI에서 안정적으로 실행 가능한 형태가 필요하다.

## 이 작업을 통해 배울점

- Desktop build 검증과 desktop integration test 검증은 요구 환경이 다르다. 빌드는 headless로 가능해도 앱 실행 테스트는 가상 display가 필요할 수 있다.
- `xvfb-run -a`는 GitHub Actions에서 Linux desktop Flutter 테스트를 실행할 때 포트/display 충돌을 줄이는 실용적인 기본값이다.
- CI workflow에 새 테스트를 추가할 때는 테스트 코드뿐 아니라 runner 환경도 같이 검증해야 한다.

## 검증

- `flutter analyze`
- `git diff --check`
