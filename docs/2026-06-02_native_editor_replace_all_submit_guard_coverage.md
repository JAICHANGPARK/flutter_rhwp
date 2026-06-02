# 2026-06-02 native editor replace all submit guard coverage

## 작업한 내용

- Flutter-native editor의 replace field에서 Ctrl/Cmd+Enter로 Replace all을 실행한 직후 `TextField.onSubmitted`가 같은 입력으로 전달되는 테스트 케이스를 추가했다.
- duplicate submit이 들어와도 replace-all command가 한 번만 기록되고, match가 모두 사라진 뒤 replace field focus가 내려가는지 검증했다.
- `CHANGELOG.md`에 검증 범위를 반영했다.

## 이 작업을 진행한 이유

일반 replace Enter 경로에는 duplicate submit guard와 focus 복원 테스트가 있었지만, Ctrl/Cmd+Enter replace-all 경로는 같은 Flutter desktop 입력 시퀀스를 별도로 검증하지 않았다. Replace all은 여러 command를 한 번에 생성하므로 duplicate submit이 생기면 문서 변경과 undo history가 크게 어긋날 수 있다.

## 이 작업을 통해 배울점

- 일반 replace와 replace all은 같은 replace field를 쓰지만, command 수와 focus 종료 정책이 다르므로 별도 테스트가 필요하다.
- Flutter-native editor의 입력 안정성은 구현 코드뿐 아니라 platform input event 조합을 재현하는 widget test로 유지해야 한다.
- WebView fallback을 유지하더라도 native editor parity는 이런 작은 keyboard/focus invariant를 누적해서 확보해야 한다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor replaces all search matches"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
