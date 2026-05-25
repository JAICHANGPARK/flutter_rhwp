# 2026-05-26 Native Editor Overwrite Mode

## 작업한 내용

- Flutter-native editor에 Insert/Overwrite 입력 모드를 추가했다.
- 상태바의 입력 모드 표시가 `Insert`, `Overwrite`, `Selection`으로 실제 editor 상태를 반영하도록 했다.
- Insert 키로 overwrite 모드를 토글하고, 본문 collapsed cursor에서 overwrite 입력 시 커서 뒤 텍스트를 `deleteText`로 먼저 삭제한 뒤 같은 위치에 `insertText`를 실행하도록 연결했다.
- overwrite 입력 중에도 pending delete mask와 pending text overlay가 같이 표시되도록 했다.
- Insert 키 토글과 overwrite 입력 command 순서를 검증하는 widget test를 추가했다.

## 이 작업을 진행한 이유

기존 상태바에는 `Insert`가 표시됐지만 실제 overwrite 모드가 없었다. HWP형 데스크톱 에디터에서는 Insert/Overwrite 모드가 기본 입력 UX에 가깝고, Flutter-native editor가 upstream 웹 에디터를 대체하려면 상태 표시와 실제 편집 command가 일치해야 한다.

## 이 작업을 통해 배울점

- 에디터 상태바는 단순 표시가 아니라 실제 입력 동작과 맞아야 사용자가 현재 편집 모드를 신뢰할 수 있다.
- overwrite는 문자열 삽입 API만으로 처리할 수 없고, 문단 끝을 넘지 않는 범위에서 삭제 command와 삽입 command를 한 edit transaction으로 묶어야 한다.
- 렌더 refresh를 지연하는 구조에서는 삭제 영역과 삽입 텍스트를 각각 optimistic overlay로 보여줘야 입력 직후 화면이 자연스럽다.
