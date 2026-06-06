# Native editor page border/fill

## 작업한 내용

- vendored rhwp core에 `get_page_border_fill_native`와 `set_page_border_fill_native`를 추가했다.
- Rust facade command에 `getPageBorderFill`과 `setPageBorderFill`을 추가했다.
- Dart 공개 API에 `RhwpBorderLine`, `RhwpPageBorderFill`, `RhwpDocument.pageBorderFill()`, `RhwpDocument.setPageBorderFill()`을 추가했다.
- Flutter-native Page 리본에 `Page border/background` 버튼과 다이얼로그를 추가했다.
- 다이얼로그에서 쪽 테두리 간격, 동일 테두리 선 종류/굵기/색상, 단색 배경 채우기 또는 채우기 없음 설정을 적용할 수 있게 했다.
- Rust facade, Dart command serialization, document wrapper, widget dialog 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream Web editor의 Page 메뉴에는 `쪽 테두리/배경`이 기본 기능으로 들어 있다. Flutter-native editor가 WebView fallback 없이 실제 편집기로 쓰이려면 page setup과 page hide뿐 아니라 문서의 쪽 배경과 테두리 설정도 command API로 다룰 수 있어야 한다.

rhwp core에는 이미 `SectionDef.page_border_fill` 모델과 `BorderFill` DocInfo 구조가 있었지만, Flutter plugin이 호출할 수 있는 native get/set API가 없었다. 이번 작업은 새 문서 구조를 만들기보다 기존 HWP 모델의 `PageBorderFill.border_fill_id` 참조를 공개 command로 노출하는 데 집중했다.

## 이 작업을 통해 배울점

- HWP의 쪽 테두리/배경은 section의 `PageBorderFill`이 DocInfo `BorderFill`을 1-based id로 참조하는 구조다.
- 표 셀 배경/테두리와 같은 `BorderFill` payload를 재사용하면 Dart API와 toolbar 명세가 단순해진다.
- Flutter UI는 우선 동일 테두리와 단색 배경만 제공해도 command surface를 안정화할 수 있다.
- 개별 방향 테두리 UI, 이미지 채우기, 그라데이션, 무늬 상세 설정은 별도 작업으로 분리하는 편이 안전하다.
- 이번 변경은 `rust/vendor/rhwp` 소스를 실제로 수정했으므로 `rust/target`과 달리 vendor 변경분도 커밋 대상이다.

## 검증

```sh
cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens
dart analyze
flutter test test/flutter_rhwp_test.dart --plain-name "page border fill commands serialize to the Rust envelope"
flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor page ribbon applies page border and fill"
```

`flutter_rust_bridge_codegen generate --no-deps-check`는 현재 Codex 세션에서 내부 `flutter --version`이 Flutter SDK cache 파일을 쓰려고 하면서 권한 오류로 실패했다. 이번 변경은 FRB 공개 함수 시그니처가 바뀌지 않고 `RhwpSession.applyCommand(commandJson)` 내부 command enum만 확장했기 때문에 generated bridge 재생성은 필요하지 않았다.
