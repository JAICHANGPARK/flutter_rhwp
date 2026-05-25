# 2026-05-25 native editor geometry vertical navigation

## 작업한 내용

- `RhwpNativeEditor`의 ArrowUp/ArrowDown 이동을 문단 순서 기반에서 page layer tree의 text run 좌표 기반으로 개선했다.
- 현재 caret의 page 좌표를 계산한 뒤 같은 page에서 화면상 위/아래에 가장 가까운 body text run을 찾는다.
- 같은 page에 대상 줄이 없으면 이전/다음 page의 가장 가까운 text run으로 이동한다.
- layer tree에서 현재 caret 위치를 찾지 못하는 경우에는 기존 문단 순서 기반 이동으로 fallback한다.
- widget test에서 source paragraph 순서와 화면 y 위치가 다른 fixture를 사용해, 이동이 문단 번호가 아니라 렌더링 geometry를 따른다는 점을 검증했다.
- page 경계를 넘는 ArrowUp/ArrowDown 이동도 widget test로 검증했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터가 WebView 없이 실제 문서 편집기처럼 동작하려면 키보드 navigation이 문서 model뿐 아니라 화면 layout을 따라야 한다.
- upstream 웹 에디터도 렌더링 결과의 text geometry를 기반으로 caret과 selection을 처리하므로, Flutter 포팅에서도 page layer tree가 핵심 기준이 되어야 한다.
- 문단 순서 fallback은 유지해서 geometry가 부족한 문서나 테스트 fixture에서도 기존 동작을 잃지 않도록 했다.

## 이 작업을 통해 배울점

- WYSIWYG 에디터에서 세로 이동은 section/paragraph 순서만으로는 부족하고 caret x 좌표와 line y 좌표를 함께 고려해야 한다.
- page layer tree가 text run bounds와 cluster advance를 제공하면 Flutter 위젯에서도 DOM 없이 hit-test와 keyboard movement를 구현할 수 있다.
- geometry 기반 구현에도 fallback 경로를 둬야 실제 문서별 layer tree 품질 차이를 견딜 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves vertically by page geometry"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves vertically"`
