# Native editor dirty status indicator

## 작업한 내용

- Flutter-native editor status bar에 수정됨 표시를 추가했다.
- 표시 상태는 `RhwpEditorController.dirty`를 기준으로 한다.
- Rust-backed edit command 후에는 status bar에 modified indicator가 나타난다.
- PDF export처럼 저장이 아닌 작업 뒤에는 indicator를 유지한다.
- HWP/HWPX save export 또는 document replacement 후에는 indicator가 사라진다.
- widget test로 dirty 상태와 status bar indicator가 함께 켜지고 꺼지는지 검증했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView fallback 없이 실제 문서 편집 UI로 쓰이려면 앱 콜백만으로는 부족하다. 사용자가 현재 문서가 저장되지 않은 상태인지 editor surface 안에서 바로 확인할 수 있어야 한다.

이전 작업에서 `onDirtyChanged`와 `RhwpEditorController.dirty`를 만들었고, 이번 작업은 그 상태를 native editor status bar UI에 연결했다. 이렇게 하면 host app의 파일 guard와 editor 내부 시각 상태가 같은 source of truth를 공유한다.

## 이 작업을 통해 배울점

- dirty 상태는 앱 통합 API이면서 동시에 editor UX 상태다. controller state를 status bar에 직접 연결하면 두 흐름이 어긋날 가능성이 줄어든다.
- PDF/DOCX/Text/SVG export는 저장 완료가 아니므로 modified indicator를 유지해야 사용자가 HWP/HWPX 저장을 놓치지 않는다.
- status bar처럼 반복적으로 보는 UI는 큰 문구보다 짧은 indicator와 tooltip이 더 적합하다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reports dirty state for edits and saves"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reports clean state when document is replaced"
```
