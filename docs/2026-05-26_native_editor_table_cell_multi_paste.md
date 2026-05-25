# 2026-05-26 native editor table cell multi paste

## 작업한 내용

- `RhwpNativeEditor`에서 선택된 표 셀에 탭/줄바꿈이 포함된 clipboard text를 붙여넣으면 여러 셀로 분배하도록 했다.
- 붙여넣기 대상 셀에 기존 text run이 있으면 `deleteTextInTableCell`로 먼저 지우고, 각 셀에 `insertTextInTableCell`을 실행한다.
- 병합 셀처럼 같은 model cell이 여러 격자 좌표에 걸릴 수 있어 `modelCellIndex` 기준으로 중복 삽입을 막았다.
- 단일 plain text 붙여넣기와 active cell text editing 상태의 붙여넣기는 기존처럼 한 셀에 삽입되도록 유지했다.

## 이 작업을 진행한 이유

upstream 웹 에디터는 `web` 폴더에 `clipboard_test.html`, `editor.js`, `text_selection.js` 같은 브라우저 기반 편집 레이어를 두고 있다. Flutter-native editor도 WebView 없이 실제 편집기로 가려면 표 셀 복사 결과인 탭/줄바꿈 텍스트를 다시 표 격자로 붙여넣는 기본 편집 흐름이 필요하다.

기존 구현은 표 셀 복사는 탭/줄바꿈 형태로 만들면서 붙여넣기는 그 문자열 전체를 active cell 하나에 넣었다. 이 상태에서는 표 일부를 복사해 다른 위치에 붙여넣는 편집 동작이 문서 편집기답게 작동하지 않는다.

## 이 작업을 통해 배울 점

- 표 clipboard는 일반 문단 clipboard와 다르게 격자 구조를 보존해야 한다.
- Flutter overlay의 셀 선택 좌표와 Rust command의 `modelCellIndex`를 함께 써야 병합 셀, span 셀에서도 중복 삽입을 피할 수 있다.
- 여러 셀을 바꾸는 편집도 하나의 deferred refresh로 묶어야 입력 중 페이지 SVG가 불필요하게 다시 렌더링되지 않는다.

## 검증

- `RhwpNativeEditor pastes clipboard table text across cells` 위젯 테스트를 추가했다.
- 테스트는 `A\tB\nC\tD` clipboard text가 2x2 표 셀에 분배되고, 기존 셀 텍스트 삭제 후 네 개의 `insertTextInTableCell` command가 발생하는지 확인한다.
