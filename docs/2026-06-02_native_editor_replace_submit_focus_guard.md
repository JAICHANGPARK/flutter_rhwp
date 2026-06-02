# 2026-06-02 native editor replace submit focus guard

## 작업한 내용

- Flutter-native editor의 replace field에서 Enter key event와 `TextField.onSubmitted`가 같은 입력으로 이어질 때 duplicate submit을 건너뛰도록 한 기존 guard에 focus 복원 정책을 추가했다.
- replacement 이후 search match가 남아 있으면 replace field focus를 유지하고, 마지막 match나 replace all 이후에는 editor focus로 되돌리도록 했다.
- replace field widget test에서 key event 직후 submit action이 들어와도 command가 한 번만 기록되는지 검증했다.
- `CHANGELOG.md`에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

Flutter desktop 입력 경로에서는 `Focus.onKeyEvent`와 `TextField.onSubmitted`가 한 Enter 입력에서 연달아 호출될 수 있다. duplicate submit 자체는 막고 있었지만, skipped submit이 `TextField` focus를 내린 뒤 다시 복원하지 않으면 upstream editor와 같은 반복 치환 흐름이 깨질 수 있다.

## 이 작업을 통해 배울점

- duplicate submit guard는 command 중복 방지만으로 충분하지 않고, 입력 focus 정책까지 같이 유지해야 한다.
- replace field는 search field와 달리 마지막 match 처리 후 editor focus로 돌아가야 하므로 match count에 따른 focus 분기가 필요하다.
- Flutter-native editor parity는 WebView UI를 단순 복제하는 것이 아니라, Flutter 입력 이벤트 모델에서 같은 UX를 재구성하는 작업이다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles replace field enter and escape keys"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
