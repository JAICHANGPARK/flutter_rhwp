# 2026-05-26 native editor table cell delete modes

## 작업한 내용

- `RhwpTableCellSelection`에 셀 선택 상태와 셀 안 텍스트 편집 상태를 구분하는 `isTextEditing` 값을 추가했다.
- 표 셀만 선택된 상태에서 Delete/Backspace를 누르면 선택된 셀의 텍스트 전체를 `deleteTextInTableCell` command로 지우도록 했다.
- 셀 안 텍스트를 직접 탭했거나 Enter로 셀 편집에 들어간 상태에서는 기존처럼 active offset 기준의 글자 단위 삭제를 유지했다.
- 선택 셀 삭제와 셀 안 텍스트 삭제가 서로 다른 command 범위를 만드는지 위젯 테스트로 검증했다.

## 이 작업을 진행한 이유

기존 구현은 표 셀을 선택해도 Delete가 active cell의 한 글자 삭제로 들어갔다. 실제 편집기에서는 셀 자체가 선택된 상태의 Delete/Backspace는 셀 내용을 지우고, 셀 안 텍스트 편집 중에는 글자 단위 삭제가 되어야 한다.

Flutter-native editor가 WebView fallback 없이 표 편집을 담당하려면 selection mode와 text-edit mode를 명확히 분리해야 한다. 이 구분이 있어야 키보드 삭제, clipboard, 셀 이동, 텍스트 입력이 충돌하지 않는다.

## 이 작업을 통해 배울 점

- 표 편집은 “선택된 셀”과 “셀 내부 caret”이 같은 active cell index를 공유하므로 별도 mode flag가 필요하다.
- 삭제 command는 UI 상태에 따라 같은 키라도 cell 전체 범위 삭제와 글자 단위 삭제로 갈라져야 한다.
- Flutter overlay 상태는 Rust 문서 모델의 source of truth를 바꾸지 않고, 어떤 command를 보낼지 결정하는 입력 계층 역할을 해야 한다.

## 검증

- `RhwpNativeEditor clears selected table cell text with delete` 위젯 테스트를 추가했다.
- `RhwpNativeEditor taps table cell text to set cell edit offset` 테스트에 active text editing 상태의 글자 단위 Delete 검증을 추가했다.
