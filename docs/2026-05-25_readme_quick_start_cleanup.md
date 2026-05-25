# README Quick Start Cleanup

## 작업한 내용

- README를 패키지 소개, 기능, 설치, Quick Start, 사용법, example, notes, license 중심으로 줄였다.
- 구현 이력, CI 상세, 긴 제약 설명은 README에서 제거하고 `docs/`와 CHANGELOG에 남기도록 정리했다.
- `RhwpFullEditor`, `RhwpViewer`, `RhwpCommandEditor`, export metadata 사용 예시만 남겼다.

## 이 작업을 진행한 이유

README는 처음 보는 사용자가 이 패키지가 무엇이고 어떻게 시작하는지 빠르게 파악하는 문서여야 한다.
작업 로그와 내부 구현 설명이 많으면 설치와 사용법이 묻혀서 실제 사용성이 떨어진다.

## 이 작업을 통해 배울점

- README는 상세 설계 문서가 아니라 진입점이다.
- 긴 구현 배경은 `docs/날짜_작업명.md`로 분리하면 README를 짧게 유지할 수 있다.
- 예제 코드는 한 화면 안에서 복사해 실행할 수 있을 정도로만 유지하는 편이 좋다.

## 검증

- `git diff --check`
