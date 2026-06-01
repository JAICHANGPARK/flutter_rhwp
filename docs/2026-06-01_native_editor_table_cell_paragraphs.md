# Native Editor Table Cell Paragraphs

## 작업한 내용

- `RhwpCommand.splitParagraphInTableCell`, `mergeParagraphInTableCell`,
  `getCellParagraphCount`, `getCellParagraphLength`를 추가했다.
- `RhwpDocument`에 표 셀 내부 문단 split/merge와 문단 수/길이 조회 API를 추가했다.
- Rust FRB command bridge에서 rhwp core의 셀 문단 API를 호출하도록 연결했다.
- `RhwpNativeEditor`에서 active table cell text edit 상태일 때 Enter가 셀 내부 문단을 나누고, 두 번째 이후 셀 문단의 시작에서 Backspace가 이전 문단과 병합되도록 했다.
- Dart command/API 테스트, Flutter widget key-flow 테스트, Rust bridge round-trip 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream web editor는 표 셀 내부에서도 일반 본문처럼 문단 단위 편집을 지원한다. Flutter-native editor가 WebView fallback을 줄여가려면 셀 텍스트 입력이 한 줄 삽입/삭제에 머물지 않고, 셀 내부 문단 구조까지 Rust 문서 모델에 직접 반영해야 한다.

## 이 작업을 통해 배울 점

- 표 셀 내부 편집은 본문 문단 편집과 별도 command envelope가 필요하다.
- 선택된 표 셀과 active text-edit cell을 구분하지 않으면 Enter가 “셀 편집 진입”과 “셀 문단 나누기”를 잘못 섞게 된다.
- Flutter 입력 계층은 키 의미를 판단하고, 실제 문서 구조 변경은 rhwp core command에 위임하는 구조가 가장 안정적이다.
