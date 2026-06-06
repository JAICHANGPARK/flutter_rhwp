# Native editor table caption removal

## 작업한 내용

- vendored rhwp core의 `set_table_properties_native`가 `hasCaption:false`를 받으면 기존 표 캡션을 제거하도록 수정했다.
- 표 캡션 제거 시 table attr의 caption 존재 bit를 함께 해제하고 table dirty 상태를 갱신하도록 했다.
- `RhwpNativeEditor` 표 속성 dialog에서 Caption 스위치를 끄고 적용하면 `setTableProperties` payload에 `hasCaption:false`가 전달되는 widget test를 추가했다.
- `CHANGELOG.md`, `docs/API_SPEC.md`, `docs/NATIVE_EDITOR_PARITY.md`, `docs/TODO.md`에 표 캡션 삭제 지원 범위를 반영했다.

## 이 작업을 진행한 이유

Flutter-native 표 속성 dialog는 이미 Caption 스위치를 제공하지만, core가 `hasCaption:false`를 삭제로 처리하지 않으면 사용자가 캡션을 끄더라도 실제 문서 모델에는 캡션이 남는다. WebView 없이 Flutter-native editor를 실사용 가능한 편집기로 만들려면 UI 토글과 저장되는 문서 모델의 의미가 일치해야 한다.

## 이 작업을 통해 배울점

- 캡션 UI는 생성뿐 아니라 제거까지 닫혀야 편집 동작으로 볼 수 있다.
- HWP table attr에는 caption 존재 여부를 나타내는 bit가 있으므로 모델의 `caption = None` 처리와 attr bit 해제를 함께 해야 한다.
- 기존 dialog가 보내는 caption direction/width/spacing 값은 `hasCaption:false`일 때 core에서 안전하게 무시되어야 한다.

## 검증

```sh
dart analyze
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor table properties can remove captions"
cargo check --manifest-path rust/Cargo.toml
```
