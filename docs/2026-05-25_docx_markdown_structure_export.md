# 2026-05-25 DOCX Markdown Structure Export

## 작업한 내용

- DOCX export가 `extract_page_text_native()` 대신 `extract_page_markdown_native()` 결과를 우선 사용하도록 변경했다.
- Markdown heading을 Word paragraph style(`Heading1`-`Heading6`)이 붙은 OOXML paragraph로 변환한다.
- Markdown pipe table을 Word `<w:tbl>` 구조로 변환하고, header row는 bold run으로 표시한다.
- Markdown이 비어 있는 page는 기존처럼 text extraction으로 fallback한다.
- Rust facade test에 heading/table OOXML 구조와 XML escaping 검증을 추가했다.
- README와 CHANGELOG에 DOCX export의 현재 범위와 남은 한계를 갱신했다.

## 이 작업을 진행한 이유

- 초기 목표에서 DOCX는 픽셀 동일성보다 의미 구조 보존을 우선한다고 정의했다.
- 기존 구현은 모든 내용을 단순 paragraph run으로만 넣어서 표나 제목 같은 구조가 Word 문서에 반영되지 않았다.
- upstream rhwp가 이미 Markdown extraction API를 제공하므로, 이를 DOCX 변환 입력으로 쓰면 별도 HWP 내부 구조 접근 없이도 의미 구조 보존을 한 단계 높일 수 있다.

## 이 작업을 통해 배울점

- DOCX 변환은 layout 보존과 semantic 보존을 분리해서 단계적으로 개선하는 편이 현실적이다.
- Markdown은 HWP 내부 구조 전체를 대체하지는 못하지만, 제목과 간단한 표를 OOXML 구조로 매핑하는 중간 IR 역할은 할 수 있다.
- XML escaping과 OOXML package 구조 테스트를 함께 두면 Word 호환성 회귀를 더 빨리 잡을 수 있다.

## 검증

- `cargo fmt --manifest-path rust/Cargo.toml`
- `cargo test --manifest-path rust/Cargo.toml`
- `flutter analyze`
- `flutter test`
- `git diff --check`
