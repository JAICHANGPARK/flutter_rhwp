# 2026-06-02 native editor horizontal paragraph navigation

## 작업한 내용

- Flutter-native editor의 좌/우 방향키 이동이 문단 경계를 넘을 수 있도록 변경했다.
- 문단 끝에서 오른쪽 방향키를 누르면 다음 문단 시작으로 이동하고, 문단 시작에서 왼쪽 방향키를 누르면 이전 문단 끝으로 이동한다.
- visible page layer에 없는 빈 문단은 rhwp core의 paragraph count/length metric을 fallback으로 사용한다.
- caret 이동 중 호출되는 viewer `goToPage`가 stale visible-page sync에 의해 바로 되돌아가지 않도록 programmatic scroll guard를 추가했다.
- 일반 문단 경계와 빈 문단 경계 이동 테스트를 추가했다.

## 이 작업을 진행한 이유

기존 좌/우 방향키 이동은 현재 paragraph offset만 증감했다. 이 방식은 문단 끝에서 다음 문단으로 넘어가지 못하고, 빈 문단처럼 SVG text run에 나타나지 않는 구조적 문단을 키보드로 지나갈 수도 없다.

Flutter-native editor를 WebView 없는 실제 편집기로 키우려면 입력뿐 아니라 caret 이동이 문서 구조를 따라야 한다. 렌더링 layer tree는 보이는 텍스트 위치를 제공하고, 문서 구조가 부족한 곳은 Rust core metric으로 보강하는 방식이 현재 구조와 가장 잘 맞는다.

## 이 작업을 통해 배울점

- caret 이동은 단순 offset 조작이 아니라 문단 구조와 page geometry를 함께 봐야 한다.
- visible layer tree만 사용하면 빈 문단, 숨은 문단, 렌더링 생략 케이스를 놓칠 수 있다.
- core paragraph metric은 삭제/병합뿐 아니라 키보드 navigation fallback에도 재사용할 수 있다.
- Flutter-native editor 포팅은 command 실행뿐 아니라 transient selection/caret 상태를 실제 문서 모델에 맞춰 갱신하는 작업이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves horizontally across paragraphs"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor moves horizontally across empty paragraphs"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles keyboard navigation and delete"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer controller scrolls to requested page"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles page up and page down keys"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles document boundary shortcuts"`
- `flutter analyze`
- `git diff --check`
