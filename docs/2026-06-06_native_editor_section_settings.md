# Native editor section settings

## 작업한 내용

- Rust facade에 `getSectionDef`와 `setSectionDef` JSON command를 추가했다.
- Dart 공개 API에 `RhwpSectionDef`, `document.sectionDef(...)`, `document.setSectionDef(...)`를 추가했다.
- Flutter-native Page 리본에 `Section settings` 버튼과 구역 설정 dialog를 추가했다.
- dialog에서 쪽/그림/표/수식 시작 번호, 쪽 번호 종류, 단 간격, 기본 탭 간격, 머리말/꼬리말/바탕쪽/테두리/채움/빈 줄 감춤 flags를 수정할 수 있게 했다.
- Rust command test와 Flutter widget test로 조회/설정 command payload를 검증했다.

## 이 작업을 진행한 이유

WebView 없이 Flutter-native editor를 완성하려면 Page 탭의 구역 단위 설정도 Flutter 위젯과 Rust command API로 제어할 수 있어야 한다. upstream rhwp core에는 이미 SectionDef 조회/설정 API가 있으므로, JS/WebView를 통하지 않고 플러그인의 command API로 노출하는 것이 맞다.

## 이 작업을 통해 배울점

- SectionDef는 page setup과 겹치는 듯 보이지만 시작 번호, 감춤 flags, 탭 간격처럼 별도 section metadata를 가진다.
- native editor dialog는 조회 command로 현재 상태를 읽고, 적용 시 `_runEdit`로 들어가야 undo/dirty/re-render 흐름과 맞는다.
- 전체 HWP SectionDef 옵션을 한 번에 구현하기보다, upstream core가 이미 JSON으로 다루는 안정 필드부터 노출하는 방식이 안전하다.

## 검증

```sh
cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor page ribbon applies section settings"
flutter analyze
```
