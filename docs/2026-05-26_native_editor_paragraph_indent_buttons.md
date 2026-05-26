# 2026-05-26 Native Editor Paragraph Indent Buttons

## 작업한 내용

- Flutter-native editor 서식 리본의 문단 모양 그룹에 들여쓰기 감소/증가 버튼을 추가했다.
- 버튼은 현재 문단의 왼쪽 여백(`marginLeft`)을 1000 HWP unit 단위로 조정하고 기존 `_applyParagraphFormat` 경로를 재사용한다.
- 선택된 여러 문단에 대해 `applyParaFormatRange` command가 발생하는 widget 테스트를 추가했다.
- README와 CHANGELOG에 문단 들여쓰기 버튼 지원 내용을 반영했다.

## 이 작업을 진행한 이유

upstream rhwp 웹 에디터의 서식 툴바에는 문단 정렬과 줄간격 사이에 들여쓰기 조작 버튼이 있다. Flutter-native editor가 WebView 없이 실제 편집기처럼 쓰이려면 문단 모양 다이얼로그를 열지 않고도 자주 쓰는 문단 여백 조정을 바로 수행할 수 있어야 한다.

## 이 작업을 통해 배울점

- 문단 들여쓰기는 새 Rust command가 아니라 기존 paragraph format command의 `marginLeft` 속성으로 충분히 표현할 수 있다.
- Flutter-native editor 포팅은 UI 버튼을 추가하는 작업처럼 보여도 선택 범위와 표 셀 경로까지 기존 command 추상화를 재사용하는 방향이 유지보수에 유리하다.
- upstream 웹 에디터의 도구 막대 기능을 Flutter로 옮길 때는 visible UI, command envelope, 테스트 fake session을 한 번에 맞춰야 한다.
