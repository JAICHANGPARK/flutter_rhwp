# 2026-06-02 native editor clear search focus

## 작업한 내용

- Flutter-native editor에서 search clear action을 실행할 때 search field뿐 아니라 replace field focus도 명시적으로 정리하도록 했다.
- replace field가 활성화된 상태에서 search clear button을 눌러도 editor surface focus로 복귀하는 widget test를 추가했다.
- clear 이후 `Ctrl/Cmd+G` editor shortcut이 바로 동작하는지 검증했다.
- `CHANGELOG.md`에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

tools ribbon의 검색/치환 입력창은 field keyboard action에서는 focus를 유지해야 하지만, clear button은 검색 상태를 종료하는 명령이다. replace field가 활성화된 상태에서도 clear 이후에는 문서 편집 surface로 돌아가야 후속 편집 단축키가 자연스럽게 이어진다.

## 이 작업을 통해 배울점

- search field와 replace field는 같은 tools ribbon 상태를 공유하므로, 검색 종료 명령에서는 두 focus node를 모두 정리해야 한다.
- Flutter-native editor에서는 command 결과와 함께 후속 shortcut focus 상태까지 테스트해야 WebView editor fallback에 가까운 사용감을 만들 수 있다.
- 작은 focus invariant를 명시적으로 고정하면 desktop input event 차이에 따른 회귀를 줄일 수 있다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor clear search restores editor focus"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
