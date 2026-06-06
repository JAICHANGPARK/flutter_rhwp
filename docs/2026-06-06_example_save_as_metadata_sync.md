# Example Save As metadata sync

## 작업한 내용

- example 앱에 `RhwpExampleAppController`를 추가해 widget test에서 Save As 동작을 직접 호출할 수 있게 했다.
- example 앱에 초기 `RhwpDocument`, 파일명, source bytes, 파일 경로를 주입하는 테스트용 진입점을 추가했다.
- example 앱의 저장 callback을 주입할 수 있게 해 native file dialog 없이 Save As 결과를 검증하도록 했다.
- HWP/HWPX primary save가 완료되면 저장된 파일명을 rhwp core의 `fileName` metadata에도 `setFileName`으로 동기화한다.
- 기본 로컬 파일 저장 경로에서는 metadata 동기화 후 다시 export해서 저장 파일 bytes도 최신 metadata를 반영하도록 보정한다.
- Save As HWPX 후 metadata, status, export intent, 표시 파일명이 갱신되는 example widget test를 추가했다.

## 이 작업을 진행한 이유

Save As는 UI에 보이는 파일명만 바뀌면 충분하지 않다. 이후 Ctrl/Cmd+S, editor mode switch, export metadata가 같은 문서 이름을 기준으로 움직여야 하므로 example 앱이 저장 완료 후 rhwp core metadata까지 갱신해야 한다.

또한 example 앱은 패키지 사용자가 참고할 통합 샘플이다. 저장 dialog에 의존하는 흐름은 자동 테스트가 어렵기 때문에 controller와 save callback 주입점을 만들어 file lifecycle을 테스트 가능한 구조로 바꿨다.

## 이 작업을 통해 배울점

- 플러그인 API의 `RhwpExportIntent.saveAs`는 저장 의도만 전달하고, 최종 저장명은 host app이 결정한다.
- host app은 Save As 완료 후 UI 상태, source bytes, dirty state, rhwp core metadata를 함께 갱신해야 한다.
- 데스크톱 로컬 파일은 저장 후 재-export로 metadata mismatch를 보정할 수 있지만, Web 다운로드와 custom saver는 최종 파일명 변경을 앱이 직접 알 수 있어야 완전 보정이 가능하다.
- file dialog를 테스트에 직접 띄우지 말고, 경계면을 callback으로 분리해야 반복 가능한 widget test를 만들 수 있다.

## 남은 점

- Web 다운로드에서 사용자가 browser save prompt의 파일명을 바꾸는 경우까지 metadata와 bytes를 완전히 맞추려면 별도 save target API 설계가 필요하다.
- custom saver는 현재 저장 callback 안에서 받은 bytes를 직접 처리하므로, callback이 반환한 path를 기준으로 재-export bytes를 다시 전달하는 확장 API를 검토해야 한다.

## 검증

```sh
flutter analyze
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon exports save artifacts"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reports dirty state for edits and saves"
flutter test test/flutter_rhwp_test.dart --plain-name "document exportDocument returns bytes with save metadata"
cd example && flutter test test/widget_test.dart
```
