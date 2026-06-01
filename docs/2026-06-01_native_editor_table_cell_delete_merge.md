# Native Editor Table Cell Delete Merge

## 작업한 내용

- `RhwpNativeEditor`에서 active table cell 문단 끝에서 Delete를 누르면 다음 셀 문단을 현재 문단으로 병합하도록 했다.
- 일반 셀 텍스트 Delete 경로에는 불필요한 조회 command가 섞이지 않도록 page layer tree의 active 문단 끝 offset을 먼저 확인한다.
- 다음 셀 문단 존재 여부는 `cellParagraphCount`로 확인하고, 실제 병합은 기존 `mergeParagraphInTableCell` command를 사용한다.
- 관련 Flutter widget key-flow 테스트를 확장했다.

## 이 작업을 진행한 이유

이전 작업에서 Enter로 셀 내부 문단을 나누고 Backspace로 이전 문단과 병합하는 흐름을 추가했다. 문서 편집기에서는 Delete도 문단 끝에서 다음 문단을 병합해야 하므로, Flutter-native editor의 표 셀 입력 UX를 본문 문단 편집과 같은 방향으로 맞췄다.

## 이 작업을 통해 배울 점

- 키 입력 의미는 현재 offset이 문단 내부인지 끝인지에 따라 달라진다.
- 렌더 layer tree에서 알 수 있는 문단 끝 정보로 먼저 분기하면 read command를 줄일 수 있다.
- 다음 문단 병합은 별도 Rust API 없이 “다음 문단을 이전 문단에 병합”하는 기존 core command를 호출하면 된다.
