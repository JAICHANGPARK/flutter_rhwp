# 2026-06-06 native editor table cell hyperlink editing

## 작업한 내용

- 활성 표 셀 텍스트 caret에서 `RhwpNativeEditor` tools ribbon의 하이퍼링크
  편집 dialog가 `fieldInfoAtInTableCell(...)`를 통해 field id를 찾는 흐름을
  widget test로 고정했다.
- 표 셀 내부에 삽입한 hyperlink field를 Rust `updateHyperlink` command로
  수정하고, 다시 `getFieldInfoAtInTableCell`로 hyperlink field를 확인하는 smoke
  test를 추가했다.
- `README.md`, `CHANGELOG.md`, `docs/API_SPEC.md`,
  `docs/NATIVE_EDITOR_PARITY.md`, `docs/TODO.md`에 표 셀 하이퍼링크 편집 범위를
  반영했다.

## 이 작업을 진행한 이유

표 셀 내부 하이퍼링크 삽입은 이미 가능했지만, 편집 경로는 `fieldId` 기반으로
본문/표 셀을 공통 처리하므로 코드만 봐서는 실제 표 셀 위치가 끝까지 연결되는지
증거가 약했다. Flutter-native editor가 WebView editor를 대체하려면 삽입한
링크를 다시 수정하는 흐름까지 안정적으로 보장해야 한다.

이번 작업은 새 UI를 크게 추가하기보다, 이미 연결된 공통 API가 표 셀 nested
location에서도 실제로 동작한다는 증거를 테스트와 문서로 남겼다.

## 이 작업을 통해 배울 점

- 하이퍼링크 편집은 본문/표 셀 별도 update API가 필요하지 않다. `fieldInfoAt` 또는
  `fieldInfoAtInTableCell`로 얻은 `fieldId`를 `updateHyperlink(...)`에 넘기면
  rhwp core의 field location 탐색이 실제 문단 위치를 찾아 처리한다.
- 표 셀 위치의 기능은 UI 테스트만으로는 부족하다. Rust smoke test에서 nested
  field location의 update path를 같이 검증해야 이후 리팩터링 시 회귀를 줄일 수
  있다.
- 남은 위험은 HWP/HWPX 저장 후 다시 열었을 때 같은 field marker와 range가
  보존되는 round-trip이다. 이 검증은 별도 backlog로 유지한다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor tools ribbon edits table cell hyperlinks"`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
