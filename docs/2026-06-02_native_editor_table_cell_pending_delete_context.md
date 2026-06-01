# 2026-06-02 Native Editor Table Cell Pending Delete Context

## 작업한 내용

- `RhwpLayerTree.selectionRectsForRange`에 table-cell text context 필터를 추가했다.
- Flutter-native editor의 pending deletion overlay가 표 셀 텍스트 삭제 시 cell context를 보존하도록 변경했다.
- 선택 텍스트 교체, overwrite 삭제, 단일 글자 삭제, 단어 삭제 경로에서 같은 cell context를 사용하도록 연결했다.
- body paragraph와 table-cell paragraph가 같은 section/paragraph 값을 공유해도 deletion mask가 표 셀 위치에 그려지는 테스트를 추가했다.

## 이 작업을 진행한 이유

- 직전 작업에서 입력 preview는 cell context를 보존했지만, 삭제 mask는 여전히 문단 좌표만 사용했다.
- 표 셀 텍스트 삭제 직후 SVG refresh를 늦추는 동안 mask가 본문 run에 붙으면 편집 화면이 튀거나 삭제가 엉뚱한 위치에서 일어난 것처럼 보일 수 있다.
- Flutter-native editor가 WebView fallback 없이 실제 편집 surface가 되려면 입력과 삭제의 optimistic overlay가 같은 위치 체계를 따라야 한다.

## 이 작업을 통해 배울점

- 표 셀 텍스트의 pending overlay는 `section/paragraph/offset`만으로 충분하지 않고, parent paragraph와 cell paragraph를 함께 알아야 한다.
- caret, text preview, deletion mask가 같은 source context 필터를 공유해야 입력 refresh 최적화가 안정적으로 동작한다.
- 작은 overlay 보정도 사용자가 체감하는 native editor 안정성에 직접 영향을 준다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "replaces selected table cell text input"`
- `flutter test test/rhwp_widget_test.dart --plain-name "overwrites text inside selected table cell"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "page layer tree"`
- `flutter analyze`
- `git diff --check`
