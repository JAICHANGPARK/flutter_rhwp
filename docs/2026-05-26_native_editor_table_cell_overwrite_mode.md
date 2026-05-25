# 2026-05-26 Native Editor Table Cell Overwrite Mode

## 작업한 내용

- Flutter-native editor의 Insert/Overwrite 입력 모드를 active table cell text에도 적용했다.
- 표 셀 page layer tree text segment에서 active cell paragraph의 끝 offset을 계산하는 helper를 추가했다.
- Overwrite 모드에서 표 셀에 글자를 입력하면 `deleteTextInTableCell`로 커서 뒤 문자를 먼저 삭제하고 같은 위치에 `insertTextInTableCell`을 실행하도록 했다.
- 표 셀 overwrite 입력 중에도 pending delete mask와 pending text overlay가 유지되도록 했다.
- 표 셀 overwrite command 순서와 refresh 지연 동작을 검증하는 widget test를 추가했다.

## 이 작업을 진행한 이유

직전 작업에서 본문 overwrite 모드는 추가됐지만, 표 셀 텍스트 편집은 여전히 insert-only였다. HWP 문서에서는 표 안에서의 텍스트 편집 비중이 높기 때문에 입력 모드가 본문과 표 셀에서 다르게 동작하면 native editor의 일관성이 떨어진다.

## 이 작업을 통해 배울점

- 표 셀 텍스트는 parent paragraph와 cell paragraph/index를 함께 봐야 하므로, 본문 paragraph helper를 그대로 쓰면 active cell 범위를 정확히 알 수 없다.
- Flutter-native editor는 page layer tree의 `cellContext`를 활용해 표 셀 텍스트 위치와 편집 command 범위를 맞춰야 한다.
- 입력 모드는 UI 상태뿐 아니라 본문 command와 표 셀 command 양쪽에 같은 정책으로 반영되어야 한다.
