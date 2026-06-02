# 2026-06-02 native editor replace toolbar focus

## 작업한 내용

- Flutter-native editor의 replace toolbar Replace/Replace all button action을 field keyboard action과 분리했다.
- toolbar button을 누르면 search field와 replace field focus를 정리하고 editor surface로 복귀하도록 했다.
- replace field가 활성화된 상태에서 toolbar Replace button을 눌러도 후속 `Ctrl/Cmd+G` editor shortcut이 바로 동작하는 widget test를 추가했다.
- `CHANGELOG.md`에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

replace field에서 Enter를 누르는 흐름은 반복 치환을 위해 field focus를 유지해야 한다. 반대로 toolbar button은 명령 실행 후 문서 편집 surface로 돌아가는 흐름이 자연스럽다. 두 경로를 같은 callback으로만 처리하면 button action이 field keyboard focus 정책을 따라가며 후속 editor shortcut이 어긋날 수 있다.

## 이 작업을 통해 배울점

- 같은 replace command라도 field keyboard action과 toolbar button action은 focus 정책이 다르다.
- Flutter-native editor에서 WebView editor chrome을 대체하려면 버튼/키보드/field submit 경로를 분리해 UX invariant를 명시해야 한다.
- focus 회귀는 command 수뿐 아니라 후속 shortcut 동작까지 확인해야 안정적으로 잡을 수 있다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor replace toolbar restores editor focus"
flutter analyze
flutter test test/rhwp_widget_test.dart
git diff --check
```
