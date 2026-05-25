# 2026-05-26 Native Editor Multiline Body Paste

## 작업한 내용

- Flutter-native editor의 body paste 경로에서 줄바꿈이 포함된 clipboard text를 감지하도록 했다.
- `\r\n`, `\r`, `\n`을 정규화한 뒤 각 줄을 순서대로 `insertText`하고 줄 사이에는 `splitParagraph` command를 실행한다.
- 결과적으로 `AA\nBB\nCC` 같은 텍스트는 한 문단 안의 raw newline이 아니라 세 문단으로 들어간다.
- table cell paste 경로는 기존처럼 tab/newline grid paste를 우선 처리하고, body paste만 이번 변경을 적용했다.
- README와 CHANGELOG에 multiline body paste 동작을 반영했다.

## 이 작업을 진행한 이유

문서 편집기에서 여러 줄 텍스트를 붙여 넣으면 일반적으로 문단이 나뉘어야 한다. 기존 body paste는 clipboard 문자열을 한 번의 text insert로 넘겨서, HWP 문서 구조 관점에서는 실제 문단 분할이 아니라 raw newline 삽입에 가까웠다. Flutter-native editor가 WebView fallback 없이 실제 편집기로 동작하려면 paste도 문서 모델 command 단위로 변환되어야 한다.

## 이 작업을 통해 배울점

- Clipboard UX는 단순 입력보다 문서 구조 변환에 가깝다. 특히 HWP 같은 문서 포맷에서는 줄바꿈과 문단 분할을 구분해야 한다.
- Flutter-native editor는 UI 입력 이벤트를 Rust command sequence로 안전하게 매핑해야 한다.
- 같은 newline clipboard라도 table selection에서는 grid paste, body selection에서는 paragraph paste가 되어야 하므로 선택 context가 중요하다.
