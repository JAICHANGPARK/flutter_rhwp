# 2026-05-26 native editor go to page

## 작업한 내용

- `RhwpNativeEditor` 보기 리본의 쪽 이동 그룹에 직접 쪽 번호를 입력하는 `Go to page` 버튼을 추가했다.
- Ctrl/Cmd+G 단축키로 같은 쪽 찾아가기 dialog를 열 수 있도록 했다.
- 입력한 1-based page 번호를 기존 `RhwpViewerController.goToPage`의 0-based page index로 변환해서 스크롤한다.
- view ribbon 버튼과 Ctrl/Cmd+G 단축키가 status bar의 현재 쪽 표시까지 갱신하는 위젯 테스트를 추가했다.
- README와 CHANGELOG에 native editor 직접 쪽 이동 기능을 반영했다.

## 이 작업을 진행한 이유

204쪽 같은 긴 HWP 문서는 이전/다음 쪽 버튼만으로 이동하기 어렵다. WebView 기반 full editor를 fallback으로 두더라도, Flutter-native editor가 실제 편집기로 성장하려면 긴 문서 탐색을 위한 직접 쪽 이동 UI가 필요하다.

## 이 작업을 통해 배울 점

- Flutter-native editor 기능은 새 Rust command가 꼭 필요하지 않은 경우도 있다. 이미 viewer controller가 가진 page scroller를 editor UI에 연결하는 것만으로도 제품성 있는 기능이 된다.
- 사용자에게 보이는 page 번호는 1-based이고 내부 viewer index는 0-based이므로 dialog와 controller 경계에서 명확히 변환해야 한다.
- 긴 문서 UX는 렌더링 성능뿐 아니라 탐색 단축키와 상태 표시가 함께 맞아야 자연스럽다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor jumps to page from view ribbon and shortcut"`
