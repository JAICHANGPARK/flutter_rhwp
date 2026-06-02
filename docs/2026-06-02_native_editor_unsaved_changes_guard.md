# Native editor unsaved changes guard

## 작업한 내용

- Flutter-native editor에 `RhwpEditorFileAction`과 `RhwpUnsavedChangesHandler`를 추가했다.
- `RhwpEditor`, `RhwpNativeEditor`, `RhwpCommandEditor`에서 `onUnsavedChanges` 콜백을 받을 수 있게 했다.
- dirty 상태에서 New/Open/Close 파일 액션을 실행하면 host app이 먼저 저장, 폐기, 취소를 결정하도록 했다.
- example 앱의 New/Open/Close 버튼과 native editor 리본 콜백을 같은 guard 흐름에 연결했다.
- example 앱의 저장 다이얼로그가 데스크톱에서 취소되면 dirty 상태를 유지하고 pending 파일 액션도 취소하도록 했다.
- 패키지 버전을 오늘 날짜 기준 `2026.6.2`로 올렸다.
- `CHANGELOG.md` 상단을 날짜별 섹션인 `2026-06-02 (2026.6.2)`로 정리했다.
- README, CHANGELOG, widget test에 변경 사항을 반영했다.

## 이 작업을 진행한 이유

Flutter-native editor가 실제 편집기로 쓰이려면 수정 중인 문서를 New/Open/Close로 덮어쓸 때 저장 확인 흐름이 필요하다. 이전 작업에서 dirty 상태와 status indicator를 만들었지만, 파일 액션 자체를 막는 guard가 없으면 사용자가 실수로 편집 내용을 잃을 수 있다.

이번 작업은 editor 내부 dirty 상태와 host app의 파일 저장 UI를 연결한다. 플러그인은 파일 선택, 저장 위치, 다운로드 같은 플랫폼별 결정을 직접 강제하지 않고, 앱이 `onUnsavedChanges`에서 정책을 정하도록 한다.

## 이 작업을 통해 배울점

- dirty state는 표시만으로 충분하지 않고, 파일 수명주기 액션의 gate로도 써야 한다.
- Flutter plugin은 플랫폼별 파일 저장 UX를 모두 알 수 없으므로, 저장/폐기/취소 판단은 host callback으로 열어두는 편이 확장성이 좋다.
- Web 저장은 다운로드 시작 후 경로가 없을 수 있지만, 데스크톱 저장은 경로가 없으면 취소로 봐야 한다. 같은 API 결과라도 플랫폼 의미를 나눠야 한다.
- guard 콜백은 성공한 저장이나 명시적 폐기 뒤에만 dirty 상태를 정리해야 한다.
- 날짜형 버전을 쓰는 패키지에서는 changelog 섹션도 날짜 기준으로 맞춰야 작업 흐름과 릴리스 번호가 덜 헷갈린다.

## 검증

```sh
dart format lib/src/rhwp_editor.dart example/lib/main.dart test/rhwp_widget_test.dart
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file actions ask unsaved changes handler"
flutter test test/rhwp_widget_test.dart
flutter analyze
cd example && flutter test test/widget_test.dart
git diff --check
```
