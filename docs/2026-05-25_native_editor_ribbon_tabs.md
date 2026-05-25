# Native Editor Ribbon Tabs

## 작업한 내용

- `RhwpNativeEditor`의 Flutter toolbar를 탭별 ribbon 구조로 나눴다.
- 기본 탭을 `입력`으로 두고, `파일`, `편집`, `보기`, `입력`, `서식`, `쪽`, `표`, `도구` 탭을 Flutter 위젯으로 구성했다.
- 기존 한 줄 command strip에 섞여 있던 명령을 역할별 그룹으로 분리했다.
  - `입력`: 커서 위치, 텍스트 삽입/삭제, 표 만들기
  - `서식`: 글자 모양, 문단 정렬
  - `표`: 표 위치, 셀 범위, 줄/칸, 셀 병합/나누기
  - `보기`: 커서 위치와 zoom
- 렌더된 표 셀을 선택하면 toolbar가 자동으로 `표` 탭을 열어 표 편집 문맥을 보여주도록 했다.
- widget test가 새 탭 구조에서 표 편집, 서식, 문단 정렬 명령을 실행하도록 갱신했다.

## 이 작업을 진행한 이유

목표는 upstream Web editor를 WebView로 감싸는 데서 끝내는 것이 아니라, Flutter 위젯으로 실제 HWP 편집기 surface를 다시 만드는 것이다.

기존 Flutter-native editor는 기능은 늘고 있었지만 모든 명령이 하나의 가로 command strip에 섞여 있었다. 이 구조는 테스트용 command editor에는 충분하지만, 사용자가 기대하는 HWP 편집기 형태와는 거리가 있다. upstream `rhwp/web` editor도 메뉴, 툴바, 선택/입력 레이어를 분리해서 구성하므로, Flutter-native 쪽도 명령을 기능 영역별 ribbon으로 나누는 것이 다음 단계의 기반이 된다.

## 이 작업을 통해 배울점

- Web editor 포팅은 DOM을 그대로 옮기는 작업이 아니라, Flutter에서 같은 편집 문맥을 표현하는 위젯 구조를 다시 설계하는 작업이다.
- toolbar는 단순 버튼 모음이 아니라 현재 선택 문맥을 반영해야 한다. 표 셀 선택 시 `표` 탭으로 전환하는 흐름이 그 시작점이다.
- 명령 API가 먼저 준비되어 있으면 UI는 탭/그룹 단위로 재배치할 수 있다. 반대로 명령이 없는 기능은 disabled placeholder로 남겨두는 편이 범위를 명확하게 만든다.

## 검증

- `dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toolbar edits table rows and columns"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toolbar merges and splits table cells"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies character formatting"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies paragraph alignment"`
- `flutter test test/rhwp_widget_test.dart`
- `flutter test`
- `flutter analyze`
- `(cd example && flutter test)`
- `git diff --check`
