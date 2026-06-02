# 2026-06-02 native editor search enter submit guard

## 작업한 내용

- Flutter-native editor의 tools ribbon 검색 입력창에 Enter submit guard를 추가했다.
- `Focus.onKeyEvent`에서 Enter를 처리한 직후 `TextField.onSubmitted`가 같은 입력을 다시 전달해도 검색 이동을 한 번만 실행하도록 했다.
- 검색 입력 widget test에 key event와 submit action이 연달아 들어오는 케이스를 추가했다.
- `CHANGELOG.md`에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

upstream web editor는 검색 입력창에서 Enter 한 번을 다음 결과 한 번 이동으로 처리한다. Flutter `TextField`는 데스크톱 입력 경로에서 키 이벤트와 submit callback이 같은 사용자 입력으로 이어질 수 있으므로, guard가 없으면 검색 결과를 한 칸 건너뛰는 UX가 생길 수 있다.

## 이 작업을 통해 배울점

- Flutter-native editor 입력 UI는 `Focus.onKeyEvent`와 `TextField.onSubmitted`의 중복 전달 가능성을 명시적으로 다뤄야 한다.
- replace field에 적용한 submit guard 패턴은 search field에도 동일하게 적용해야 검색/치환 도구의 키보드 동작이 일관된다.
- WebView editor parity는 큰 기능뿐 아니라 Enter 같은 작은 입력 edge case를 하나씩 맞추는 방식으로 누적된다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor cycles search matches from search field keys"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
