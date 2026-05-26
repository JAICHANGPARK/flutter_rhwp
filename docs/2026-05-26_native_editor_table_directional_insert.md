# 2026-05-26 Native Editor Table Directional Insert

## 작업한 내용

- Flutter-native editor 표 리본의 줄/칸 삽입을 위/아래 줄, 왼쪽/오른쪽 칸으로 분리했다.
- 표 셀 context menu도 upstream 웹 에디터처럼 `위에 줄 삽입`, `아래에 줄 삽입`, `왼쪽에 칸 삽입`, `오른쪽에 칸 삽입` 항목을 노출하도록 바꿨다.
- 기존 Dart/Rust command의 `below` / `right` 플래그를 재사용해 새 Rust API 없이 방향별 삽입을 연결했다.
- 표 리본 command 테스트와 context menu label 테스트를 업데이트했다.

## 이 작업을 진행한 이유

upstream rhwp 웹 에디터의 표 context menu는 행과 열 삽입 방향을 명확히 구분한다. Flutter-native editor에서 아래 행/오른쪽 열만 노출하면 실제 편집자가 기대하는 표 편집 흐름과 차이가 생기므로, 같은 command surface 위에 방향별 UI를 추가했다.

## 이 작업을 통해 배울점

- 이미 command envelope에 방향 플래그가 있으면 Flutter UI는 기능을 새로 만들기보다 노출 수준을 올리는 것만으로 Web editor와 가까워질 수 있다.
- 표 편집 기능은 리본과 context menu가 같은 동작을 제공해야 마우스 중심 편집 흐름이 자연스럽다.
- upstream 포팅은 큰 기능 추가뿐 아니라 기존 기능의 방향성, 라벨, 접근 위치를 맞추는 작업도 중요하다.
