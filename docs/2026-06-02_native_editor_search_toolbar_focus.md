# 2026-06-02 native editor search toolbar focus

## 작업한 내용

- Flutter-native editor의 search toolbar find/previous/next action을 실행할 때 search field와 replace field focus를 모두 정리하도록 했다.
- replace field가 활성화된 상태에서 search toolbar next button을 눌러도 editor surface focus로 복귀하는 widget test를 추가했다.
- toolbar action 이후 `Ctrl/Cmd+G` 같은 editor shortcut이 바로 동작하는지 검증했다.
- `CHANGELOG.md`에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

검색/치환 field 안에서 Enter를 누르는 흐름은 해당 field focus를 유지해야 하지만, toolbar button은 명령 실행 후 문서 편집 surface로 돌아가는 흐름이 자연스럽다. replace field가 활성화된 상태에서 search toolbar button을 누르면 field focus가 남아 editor shortcut이 바로 이어지지 않을 수 있어 명시적으로 정리했다.

## 이 작업을 통해 배울점

- 같은 search navigation이라도 field keyboard action과 toolbar button action은 focus 정책이 다르다.
- Flutter-native editor의 toolbar는 WebView editor chrome을 대체하므로, 버튼 실행 후 편집 surface로 돌아가는 UX를 일관되게 보장해야 한다.
- focus invariant는 command 결과뿐 아니라 후속 keyboard shortcut까지 테스트해야 한다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor search toolbar restores editor focus"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
