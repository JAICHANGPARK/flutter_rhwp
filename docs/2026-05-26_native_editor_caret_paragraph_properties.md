# 2026-05-26 native editor caret paragraph properties

## 작업한 내용

- `getParaPropertiesAt`, `getCellParaPropertiesAt` Dart command/API를 추가했다.
- Rust facade에서 rhwp core의 `get_para_properties_at_native`, `get_cell_para_properties_at_native`를 command envelope로 노출했다.
- Flutter-native editor가 현재 caret 또는 active table cell의 문단 속성을 조회해서 format ribbon의 정렬 선택 상태와 줄간격 preset 상태에 반영하도록 했다.
- Dart command/document 테스트, Rust facade command 테스트, Flutter toolbar 상태 테스트를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor가 upstream web editor처럼 동작하려면 명령을 적용하는 것만으로는 부족하다. 커서를 문서 안에서 이동했을 때 현재 위치의 문단 모양이 리본 UI에 즉시 반영되어야 사용자가 문서 상태를 신뢰할 수 있다.

기존 구현은 문단 정렬과 줄간격을 적용할 수 있었지만, 현재 문단 속성을 읽어서 toolbar selected state로 보여주지 않았다. 이 작업은 Rust 문서 모델을 source of truth로 두고 Flutter UI를 동기화하는 방향으로 WYSIWYG 포팅을 한 단계 진전시킨다.

## 이 작업을 통해 배울 점

- Flutter-native 에디터는 편집 명령 API와 상태 조회 API가 함께 있어야 완성도가 올라간다.
- 표 셀 내부 문단은 본문 문단과 다른 좌표계를 쓰므로 별도 cell paragraph query가 필요하다.
- 리본 UI의 selected state는 로컬 추정값보다 Rust core에서 조회한 실제 문서 속성을 기준으로 맞추는 편이 안전하다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reflects caret paragraph properties in ribbon"`
