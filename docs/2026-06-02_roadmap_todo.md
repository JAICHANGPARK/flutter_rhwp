# Roadmap and TODO tracking

## 작업한 내용

- `docs/ROADMAP.md`를 추가해 `flutter_rhwp`의 큰 진행 영역과 완료 기준을 정리했다.
- `docs/TODO.md`를 추가해 이번 작업, 다음 우선순위, native editor parity, export/fidelity, cross-platform, release backlog를 체크리스트로 나눴다.
- README에 Roadmap, TODO, Changelog 링크를 추가했다.
- `CHANGELOG.md`에 roadmap/TODO 문서 추가를 기록했다.

## 이 작업을 진행한 이유

처음 예상보다 작업이 길어지는 이유는 플러그인 껍데기만 만드는 범위를 넘어섰기 때문이다. 현재 작업은 `rhwp`의 Web editor 경험을 Flutter-native editor로 옮기는 쪽에 가깝고, 이 경우 기능 구현뿐 아니라 실제 문서 fidelity, 저장 안정성, 플랫폼별 동작 검증이 큰 비중을 차지한다.

따라서 남은 일을 머릿속이나 대화 기록에만 두면 우선순위가 흐려진다. Roadmap은 큰 방향과 완료 기준을 보존하고, TODO는 바로 다음 작업을 고르는 기준으로 둔다.

## 이 작업을 통해 배울점

- 진행률을 말할 때는 기준을 분명히 해야 한다. SVG viewer 기준과 Web editor parity 기준은 완성도 숫자가 크게 다르다.
- 긴 기능 포팅 작업은 구현 목록보다 검증 목록이 더 오래 남는다.
- 문서에 backlog를 남기면 다음 커밋에서 어떤 기능을 잡을지, 어떤 항목이 아직 리스크인지 빠르게 판단할 수 있다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart
flutter analyze
cd example && flutter test test/widget_test.dart
git diff --check
```
