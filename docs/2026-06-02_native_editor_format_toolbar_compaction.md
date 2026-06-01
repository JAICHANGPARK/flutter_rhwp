# 2026-06-02 Native Editor Format Toolbar Compaction

## 작업한 내용

- Flutter-native 에디터의 서식 탭에서 글자색과 배경색 swatch를 popup menu로 압축했다.
- 위첨자, 아래첨자, 양각, 음각 같은 고급 글자 효과를 `Text effects` popup menu로 묶었다.
- 자주 쓰는 글자 모양 그룹을 서식 탭의 첫 그룹으로 배치하고 글꼴/크기 입력 폭을 줄여 좁은 폭에서도 핵심 컨트롤이 보이도록 조정했다.
- 글자 서식 툴바 액션 후 selection overlay의 click sequence를 reset하도록 `gestureRevision`을 추가했다.
- 툴바 조작 뒤 문서 영역을 다시 클릭해도 이전 셀 클릭과 이어져 accidental double-click selection이 발생하지 않도록 했다.

## 이 작업을 진행한 이유

기존 서식 탭은 모든 글자 효과와 색상 swatch를 한 줄에 나열해서 작은 창이나 테스트 폭에서 일부 컨트롤이 화면 밖으로 밀렸다. 또한 셀 텍스트를 클릭한 뒤 툴바를 조작하고 같은 셀을 다시 클릭하면 이전 문서 클릭과 이어져 double-click처럼 처리될 수 있었다. Flutter 위젯 기반 에디터에서는 툴바 배치와 문서 hit-test 상태를 함께 관리해야 실제 편집 흐름이 안정된다.

## 이 작업을 통해 배울점

- Flutter-native 에디터의 ribbon UI는 단순히 기능을 나열하는 것보다 좁은 폭에서의 우선순위와 메뉴화가 중요하다.
- 문서 영역의 double-click/triple-click 상태는 툴바 조작 같은 외부 편집 액션이 발생하면 끊어야 한다.
- 색상/효과처럼 선택지가 있는 도구는 popup menu로 묶으면 화면 폭을 절약하면서도 기능 접근성을 유지할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "character format"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
