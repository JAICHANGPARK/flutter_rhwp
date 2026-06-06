# Native editor Save and Save As intent

## 작업한 내용

- `RhwpExportIntent`를 추가해 `RhwpExportedDocument`가 Save, Save As, Export 흐름을 구분하도록 했다.
- `RhwpDocument.exportDocument`, `RhwpFullEditorController.exportDocument`, `RhwpWebEditorController.exportDocument`가 `intent`를 받을 수 있게 했다.
- Flutter-native editor 파일 리본을 `Save`, `Save As HWP`, `Save As HWPX`로 분리했다.
- Ctrl/Cmd+S는 현재 문서 파일명/metadata를 기준으로 HWP 또는 HWPX primary save를 선택하도록 했다.
- Ctrl/Cmd+Shift+S는 기존 동작을 유지하되 `Save As HWPX` intent로 명시했다.
- example 앱은 opened local file path를 기억하고, `RhwpExportIntent.save`에서는 가능하면 같은 경로에 직접 저장한다.
- example 앱은 HWP/HWPX primary save가 완료되면 `_sourceBytes`, 표시 파일명, dirty state를 최신 저장 결과로 갱신한다.
- save/export widget test와 export metadata unit test가 intent를 검증하도록 확장했다.

## 이 작업을 진행한 이유

Flutter-native editor를 실제 편집기처럼 쓰려면 파일 리본에서 Save와 Save As의 의미가 분리되어야 한다. 이전 구조는 모든 저장/내보내기가 `RhwpExportedDocument` 하나로만 전달되어 host app이 사용자의 의도를 알기 어려웠다.

특히 Ctrl/Cmd+S가 항상 HWP로 저장되는 흐름은 HWPX 문서를 열었을 때 형식 보존과 맞지 않는다. 이번 작업은 Flutter widget editor가 자체 파일 lifecycle을 갖추는 방향으로, host app이 같은 callback을 받더라도 `intent`를 보고 current file 저장, 다른 이름 저장, 보조 export를 다르게 처리할 수 있게 만든다.

## 이 작업을 통해 배울점

- editor UI의 Save 버튼은 단순 export 버튼이 아니라 host app과의 계약이다.
- Flutter 플러그인은 실제 파일 저장 UI를 플랫폼별 host app에 맡기더라도, 저장 의도는 public API에 명시해야 한다.
- primary HWP/HWPX save와 PDF/DOCX/Text/SVG export는 dirty state 의미가 다르다.
- 예제 앱은 단순 데모가 아니라 패키지 사용자가 따라 할 integration sample이므로 source bytes와 file name handoff를 계속 최신으로 유지해야 한다.

## 남은 점

- Save As 후 rhwp core 내부 `fileName` metadata까지 새 저장명으로 동기화할지 결정해야 한다.
- Save/Save As dialog 취소와 path 갱신 흐름은 별도 example widget test로 더 보강해야 한다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon exports save artifacts"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reports dirty state for edits and saves"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon renames document file"
flutter test test/flutter_rhwp_test.dart --plain-name "document exportDocument returns bytes with save metadata"
flutter analyze
cd example && flutter test test/widget_test.dart
git diff --check
```
