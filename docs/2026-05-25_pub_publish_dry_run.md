# Pub Publish Dry Run

## 작업한 내용

- `flutter pub publish --dry-run`으로 현재 package layout을 검증했다.
- Pub이 지적한 `flutter_rust_bridge` exact dependency constraint를 `^2.11.1`로
  완화했다.
- `docs` 디렉터리 경고는 현재 사용자 요청과 충돌하므로 남은 warning으로 기록했다.
- CHANGELOG에 pub dry-run 결과와 dependency constraint 변경을 반영했다.

## 이 작업을 진행한 이유

`flutter_rhwp`는 Flutter plugin으로 배포될 가능성이 있는 패키지다. `flutter analyze`
와 테스트가 통과해도 pub.dev package validation이 보는 항목은 다르다. 특히 dependency
constraint가 너무 좁으면 다른 Flutter 앱과 함께 사용할 때 dependency resolution을
불필요하게 어렵게 만든다.

이번 dry-run은 publish 자체가 아니라 배포 전 검증이다. 결과적으로 dependency 경고는
고쳤고, `docs` 폴더명 경고는 사용자가 작업 문서를 `docs/날짜_작업명.md` 형태로
남기길 요청했기 때문에 즉시 rename하지 않았다.

## 이 작업을 통해 배울점

- Pub validation은 테스트와 별도로 실행해야 한다. package metadata, dependency
  constraint, layout convention 같은 배포 품질 항목을 따로 확인한다.
- plugin 내부에서 생성된 FRB 코드는 특정 버전을 기준으로 만들어졌더라도, Dart package
  dependency는 가능한 호환 범위를 열어두는 편이 ecosystem에 더 맞다.
- `docs`와 `doc`처럼 도구 convention과 프로젝트 작업 방식이 충돌하는 경우에는 무리하게
  고치기보다 tradeoff를 기록하고 나중에 배포 정책으로 결정하는 편이 안전하다.

## 검증

- `flutter pub publish --dry-run`
- 첫 실행 결과: `flutter_rust_bridge` exact constraint warning, top-level `docs`
  directory layout warning
- `flutter_rust_bridge` constraint 수정 후 exact constraint warning은 사라졌다.
- clean git 상태의 temp clone에서 재실행한 결과, 남은 warning은 top-level `docs`
  directory layout warning 하나뿐이었다.
- 남은 layout warning: top-level `docs`는 Pub convention상 `doc`가 권장되지만, 이번
  프로젝트에서는 사용자가 `docs/날짜_작업명.md` 구조를 요청했으므로 유지했다.
