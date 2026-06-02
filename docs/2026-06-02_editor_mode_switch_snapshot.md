# Editor mode switch snapshot

## 작업한 내용

- example 앱에서 native editor와 full editor 사이를 전환할 때 dirty 상태를 보존하도록 했다.
- native editor에서 full editor로 전환할 때 `exportHwp()`로 만든 전환용 bytes를 full editor source로 넘기되, 외부 저장이 아니므로 dirty 상태를 지우지 않도록 했다.
- full editor에서 native editor로 돌아올 때 attached full editor controller의 `exportDocument(RhwpExportFormat.hwp)`를 먼저 호출해 최신 HWP bytes를 열도록 했다.
- full editor가 attach되지 않았고 기존 source bytes도 없는 경우에는 기존처럼 파일을 먼저 열라는 상태 메시지를 보여준다.
- `CHANGELOG.md`와 `docs/TODO.md`에 전환 snapshot 작업과 남은 dirty event bridge 작업을 반영했다.

## 이 작업을 진행한 이유

WebView/full editor fallback을 유지하면서 Flutter-native editor를 키우려면 두 editor mode 사이를 오갈 때 문서 상태가 보존되어야 한다. 이전 흐름은 native에서 full editor로 넘어가는 순간 dirty 상태를 clean으로 바꿨고, full editor에서 native로 돌아올 때도 처음 열었던 `_sourceBytes`를 다시 사용할 수 있었다.

이 방식은 사용자가 editor mode를 바꾼 뒤 저장하지 않은 변경사항을 잃을 가능성이 있다. 이번 작업은 mode switch를 외부 저장으로 취급하지 않고, full editor가 붙어 있을 때는 현재 editor 상태를 export한 bytes를 native editor로 전달하도록 바꿨다.

## 이 작업을 통해 배울점

- editor mode switch는 save가 아니라 in-memory handoff다. 따라서 dirty 상태를 함부로 지우면 안 된다.
- full editor fallback은 내부 UI가 편집을 처리하므로, native editor로 돌아올 때는 controller export를 통해 최신 bytes를 가져와야 한다.
- 아직 upstream full editor의 edit/dirty 이벤트가 Flutter controller로 들어오지는 않는다. 이 이벤트 bridge가 들어와야 full editor 단독 편집 중에도 dirty indicator와 close guard가 더 정확해진다.

## 검증

```sh
dart format example/lib/main.dart
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file actions ask unsaved changes handler"
flutter analyze
cd example && flutter test test/widget_test.dart
git diff --check
```
