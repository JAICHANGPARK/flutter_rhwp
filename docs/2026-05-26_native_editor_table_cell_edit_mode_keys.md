# 2026-05-26 native editor table cell edit mode keys

## 작업한 내용

- `RhwpTableCellSelection.copyWith`를 추가해 셀 선택 상태에서 edit-mode 플래그만 안전하게 바꿀 수 있게 했다.
- Flutter-native editor에서 선택된 표 셀에 `F5`를 누르면 `Enter`와 같이 active cell text edit 모드로 들어가도록 했다.
- active cell text edit 중 `Esc`를 누르면 표 셀 선택 자체를 지우지 않고 같은 셀 선택 상태로 돌아가도록 했다.
- `F5` 진입, `Esc` 복귀, 재진입이 문서 command를 발생시키지 않는 위젯 회귀 테스트를 추가했다.
- README와 CHANGELOG에 upstream-style 표 셀 edit mode 키 동작을 반영했다.

## 이 작업을 진행한 이유

upstream web editor는 표 셀이 선택된 상태에서 `Enter` 또는 `F5`로 셀 편집에 들어가고, 셀 내부 텍스트 편집 상태에서 `Esc`를 누르면 표 셀 선택 모드로 돌아간다. Flutter-native editor가 WebView fallback을 대체하려면 단순히 Rust command를 호출하는 것뿐 아니라 이런 editor mode 전환도 같은 감각으로 동작해야 한다.

기존 Flutter-native 동작은 `Enter` 진입은 있었지만 `F5` 진입이 없었고, `Esc`가 active cell edit 상태까지 모두 해제했다. 이러면 표 편집 중 키보드 중심 작업 흐름이 upstream과 달라진다.

## 이 작업을 통해 배울 점

- 표 편집 UX는 cell selection과 cell text editing을 별도 상태로 다뤄야 한다.
- `Esc`는 항상 “모두 지우기”가 아니라 현재 edit mode에서 한 단계 위 상태로 빠지는 키가 될 수 있다.
- Web editor parity는 큰 기능뿐 아니라 키보드 mode transition 같은 작은 규칙을 누적해서 맞춰야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor exits and re-enters table cell edit mode"`
- `flutter analyze`
