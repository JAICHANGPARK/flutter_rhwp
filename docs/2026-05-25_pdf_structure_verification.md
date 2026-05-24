# 2026-05-25 PDF Structure Verification

## 작업한 내용

- native PDF export 테스트를 `%PDF` 헤더 검사에서 PDF 구조 검사로 확장했다.
- PDF output에 version header, EOF marker, xref, catalog object, source page count와 일치하는 page object가 있는지 확인하는 helper를 추가했다.
- `rhwp_core::renderer::pdf::svgs_to_pdf()`에 2페이지 synthetic SVG 입력을 넣어 빠른 multi-page PDF 회귀 테스트를 추가했다.
- 예제 전체 HWP 문서를 PDF로 변환하는 테스트는 100초 이상 걸리는 것을 확인해 CI용 검증에서는 제외했다.

## 이 작업을 진행한 이유

- 초기 테스트 계획에는 PDF snapshot 비교가 포함되어 있었지만, 기존 테스트는 PDF처럼 보이는 바이트가 생성되는지만 확인했다.
- 완전한 시각 snapshot 비교 전이라도 PDF 문서 구조와 페이지 수를 검증하면 변환 회귀를 더 빨리 잡을 수 있다.
- 예제 정책 문서 전체 PDF export는 의미는 있지만 CI에서 매번 실행하기엔 비용이 크므로, 빠른 synthetic multi-page 입력으로 다중 페이지 결합 로직을 검증하는 편이 유지보수성이 좋다.

## 이 작업을 통해 배울점

- 변환 테스트는 무조건 큰 실사용 샘플을 돌리기보다, 빠른 구조 테스트와 무거운 시각 비교 테스트를 분리하는 편이 좋다.
- PDF는 단순 magic header보다 `startxref`, `%%EOF`, catalog, page object count를 함께 보면 훨씬 강한 smoke test가 된다.
- 큰 문서의 PDF snapshot 비교는 별도의 느린 테스트 또는 수동 검증 단계로 분리해야 CI 피드백 시간이 유지된다.

## 검증

- `cargo test --manifest-path rust/Cargo.toml api::rhwp::tests`
