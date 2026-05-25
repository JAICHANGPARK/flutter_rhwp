# 2026-05-25 Rust Layer Tree Contract Test

## 작업한 내용

- Rust facade test에 `page_layer_tree_json_exposes_editor_geometry_contract`를 추가했다.
- example HWP asset을 열고 `RhwpSession.page_layer_tree(0)` 결과가 JSON으로 파싱되는지
  검증했다.
- Flutter editor geometry가 의존하는 `schemaVersion`, `pageWidth`, `pageHeight`,
  `root.bounds`, `textSources.stableSourceKey`, `textRun.bbox`,
  `textRun.source.utf16Range`, `textRun.placement.runToPage`, `textRun.clusters` 계약을
  테스트로 고정했다.
- README의 CI 설명과 CHANGELOG를 갱신했다.

## 이 작업을 진행한 이유

Flutter editor는 page layer tree의 `stableSourceKey`와 `textRun` geometry를 사용해
document offset을 화면 좌표로 변환한다. Dart parser test만 있으면 synthetic JSON은
검증되지만, Rust facade가 실제 rhwp core에서 같은 구조를 계속 반환하는지는 보장되지 않는다.

이번 테스트는 실제 example asset을 통해 Rust facade JSON contract를 확인한다. upstream
vendored rhwp를 갱신하거나 page layer tree serializer가 바뀌면 Flutter editor가 깨지기 전에
Rust test에서 먼저 잡을 수 있다.

## 이 작업을 통해 배울점

- 브리지 기반 플러그인은 Dart API 테스트만으로 충분하지 않다. Rust facade가 반환하는 wire
  format도 별도 contract test로 고정해야 한다.
- `clusters`는 문서/텍스트 run에 따라 비어 있을 수 있으므로 필수 geometry는 `bbox`,
  `stableSourceKey`, `placement.runToPage`로 보고, cluster 배열은 존재 여부만 contract로 둔다.
- 실제 asset 기반 테스트는 synthetic fixture보다 비용이 크지만, Flutter UI가 의존하는
  cross-layer contract를 검증하는 데 효과적이다.
