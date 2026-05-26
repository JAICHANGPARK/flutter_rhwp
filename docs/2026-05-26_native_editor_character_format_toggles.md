# 2026-05-26 native editor character format toggles

## 작업한 내용

- `RhwpNativeEditor`의 서식 리본 버튼과 Ctrl/Cmd+B/I/U 단축키가 현재 caret character format을 기준으로 서식을 토글하도록 변경했다.
- 글자 모양 dialog처럼 명시적으로 값을 적용하는 경로는 그대로 두고, toolbar/context menu/shortcut 경로만 토글 전용 helper를 거치도록 분리했다.
- 선택 영역과 선택된 표 셀에 서식을 적용한 뒤 현재 toolbar 상태를 즉시 갱신하도록 optimistic character format 상태를 기록했다.
- Bold/Italic/Underline이 이미 켜진 상태에서 다시 누르면 `false` command가 나가는 위젯 테스트를 추가했다.
- README와 CHANGELOG에 Flutter-native character format toggle 동작을 반영했다.

## 이 작업을 진행한 이유

upstream web editor의 format toolbar는 Bold/Italic/Underline을 누를 때마다 켜고 끄는 방식으로 동작한다. Flutter-native editor가 WebView fallback을 점진적으로 대체하려면 버튼을 누를 때 항상 `true`만 보내는 command editor 동작이 아니라 실제 에디터에 가까운 토글 UX가 필요하다.

## 이 작업을 통해 배울 점

- 편집기에서 toolbar 버튼은 명시 값 적용 dialog와 의미가 다르다. 버튼은 현재 상태를 읽고 반대 값을 적용해야 한다.
- Rust command는 최종 값을 받아도 되고, Flutter UI는 그 값을 만들기 위한 현재 상태와 transient state를 관리해야 한다.
- 선택 영역 적용 후에는 Rust refresh/query가 끝나기 전에도 toolbar 상태를 자연스럽게 보여주기 위한 optimistic state가 필요하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toggles active character formatting off"`
