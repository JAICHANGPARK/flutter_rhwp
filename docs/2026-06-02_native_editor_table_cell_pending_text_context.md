# 2026-06-02 Native Editor Table Cell Pending Text Context

## 작업한 내용

- `RhwpLayerTree.caretRectFor`에 table-cell text context 필터를 추가했다.
- Flutter-native editor의 pending text overlay가 표 셀 입력일 때 parent paragraph, control index, cell index, cell paragraph를 보존하도록 변경했다.
- 같은 section/paragraph를 가진 body text run과 table-cell text run이 함께 있을 때 pending preview가 표 셀 위치에 붙는 widget test를 추가했다.
- layer tree 단위 테스트로 cell context를 넘긴 caret lookup이 body run이 아니라 cell run을 반환하는지 검증했다.

## 이 작업을 진행한 이유

- 표 셀 내부 텍스트는 바깥 문단 번호를 공유할 수 있어 `section/paragraph/offset`만으로는 정확한 렌더링 run을 특정하기 어렵다.
- 입력 직후 실제 SVG refresh를 늦추는 동안 pending text preview와 caret overlay가 잘못된 본문 위치에 그려지면, 사용자는 매 입력마다 화면이 튀거나 refresh되는 것처럼 느낄 수 있다.
- WebView fallback 없이 Flutter-native editor를 키우려면 optimistic input overlay도 표 셀 문맥을 정확히 따라야 한다.

## 이 작업을 통해 배울점

- HWP 표 셀 텍스트는 문서 본문 paragraph와 table-cell 내부 paragraph라는 두 좌표계를 함께 가진다.
- 렌더링 보조 정보는 단순 paragraph id보다 source context를 함께 전달해야 hit-test, caret, pending overlay가 같은 위치 체계를 공유할 수 있다.
- refresh를 늦추는 최적화는 preview 위치가 정확할 때만 편집 UX 개선으로 이어진다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "anchors pending table cell text"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "caret rect can filter"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter test test/flutter_rhwp_test.dart --plain-name "page layer tree"`
- `flutter analyze`
- `git diff --check`
