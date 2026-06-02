# 2026-06-02 native editor ruler paragraph shape

## 작업한 내용

- Flutter-native ruler 배경을 더블클릭하면 문단 모양 다이얼로그가 열리도록 연결했다.
- ruler에서 여는 다이얼로그도 현재 caret 문단의 정렬, 줄 간격, 들여쓰기, 여백, 문단 앞/뒤 간격 값을 그대로 preload한다.
- ruler marker drag와 동일하게 기존 문단 포맷 상태와 command path를 재사용했다.
- widget test로 ruler 더블클릭이 문단 모양 다이얼로그를 열고, 현재 문단 속성 값을 표시하는지 검증했다.

## 이 작업을 진행한 이유

upstream rhwp 웹 에디터처럼 ruler는 단순한 눈금 표시가 아니라 문단 설정으로 들어가는 편집기 chrome 역할도 해야 한다. Flutter-native editor를 100% Flutter 위젯으로 포팅하는 방향에서는 WebView editor fallback 없이도 ruler에서 문단 모양을 바로 조정할 수 있어야 한다.

## 이 작업을 통해 배울점

- Flutter-native editor chrome은 문서 렌더링과 별개로 현재 caret 문단 상태를 계속 반영해야 한다.
- 새 UI 진입점은 별도 command를 만들기보다 기존 다이얼로그와 문단 포맷 경로를 재사용해야 편집 상태, undo, refresh 정책이 일관된다.
- marker처럼 작은 hit target과 ruler 배경 gesture는 테스트에서 명확히 분리된 좌표를 사용해야 회귀를 안정적으로 잡을 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --name "ruler"`
