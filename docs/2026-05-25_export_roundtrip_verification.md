# 2026-05-25 Export Roundtrip Verification

## 작업한 내용

- Rust facade 테스트에서 `export_hwpx()` 결과를 다시 `open_bytes()`로 열어 HWPX round-trip을 검증하도록 보강했다.
- 번들 blank 샘플뿐 아니라 예제 앱에 포함된 `korea_ai_action_plan_2026_2028.hwp`도 HWP와 HWPX로 export한 뒤 다시 열리는지 확인했다.
- CHANGELOG에 HWP/HWPX export reopen 검증 추가 내용을 반영했다.

## 이 작업을 진행한 이유

- 초기 테스트 계획에는 HWP/HWPX round-trip 검증이 포함되어 있었지만, 기존 테스트는 HWP만 재오픈하고 HWPX는 바이트가 비어 있지 않은지만 확인했다.
- 예제 앱의 실제 샘플 문서가 열리고 렌더링되는 것과 별개로, 저장/export 결과가 다시 parser로 들어올 수 있는지 확인해야 파일 저장 기능의 신뢰도를 높일 수 있다.
- Flutter 쪽 UI 테스트보다 Rust facade 테스트에서 export 결과를 바로 재오픈하는 편이 문제 원인을 더 좁혀 볼 수 있다.

## 이 작업을 통해 배울점

- 변환 기능은 "파일이 생성됐다"보다 "생성된 파일을 다시 열 수 있다"가 더 강한 회귀 검증이다.
- 빈 샘플과 실제 정책 문서 샘플을 함께 테스트하면 serializer가 단순 문서와 실사용 문서 모두에서 최소 호환성을 유지하는지 확인할 수 있다.
- DOCX/PDF처럼 외부 뷰어 호환성이 중요한 포맷과 달리, HWP/HWPX는 같은 rhwp parser로 재오픈하는 round-trip 테스트를 빠르게 CI에 넣을 수 있다.

## 검증

- `cargo test --manifest-path rust/Cargo.toml api::rhwp::tests`
