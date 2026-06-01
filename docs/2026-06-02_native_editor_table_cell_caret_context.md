# 2026-06-02 Native Editor Table Cell Caret Context

## 작업한 내용

- Flutter-native editor의 표 셀 텍스트 편집 모드에서 caret 위치를 table-cell text context로 계산하도록 변경했다.
- IME composing preview도 표 셀 내부 caret 위치를 기준으로 표시되도록 맞췄다.
- body paragraph와 table-cell paragraph가 같은 section/paragraph 값을 공유하는 fixture에서 caret와 composing preview가 표 셀 위치에 붙는 widget test를 추가했다.

## 이 작업을 진행한 이유

- 입력/삭제 optimistic overlay는 cell context를 보존하도록 보강했지만, 기본 caret와 한글 조합 preview는 여전히 body selection caret를 기준으로 삼을 수 있었다.
- 사용자가 표 셀 안에서 입력할 때 caret 또는 조합 preview가 본문 위치에 남으면 Flutter-native editor가 실제 편집 위치를 잘못 보여준다.
- WebView fallback 없이 Flutter 위젯 기반 에디터를 쓰려면 입력 전, 입력 중, refresh 전 overlay가 모두 같은 표 셀 좌표계를 따라야 한다.

## 이 작업을 통해 배울점

- 표 셀 텍스트 편집의 caret는 body selection과 별도 상태인 `RhwpTableCellSelection`에서 계산해야 한다.
- IME 조합 UI는 최종 입력보다 먼저 보이는 피드백이라서, 위치 계산이 틀리면 한글 입력 UX가 바로 깨진다.
- pending text, pending deletion, caret, composing preview는 같은 source context 원칙을 공유해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "anchors table cell caret"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "IME composition"`
- `flutter analyze`
- `git diff --check`
