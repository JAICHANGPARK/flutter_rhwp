# 2026-06-02 Native Editor Context Pending Character Format

## 작업한 내용

- Flutter-native 에디터의 body context menu에서 선택 영역이 없어도 `굵게`, `기울임`, `밑줄`, `취소선`, `글자 모양`을 사용할 수 있게 했다.
- collapsed caret 상태에서 `글자 모양` 다이얼로그를 열 수 있게 하고, 다이얼로그 값이 다음 입력 문자에 pending character format으로 적용되도록 연결했다.
- context menu로 `굵게`를 예약한 뒤 입력한 텍스트에 `applyCharFormatRange`가 따라붙는 위젯 테스트를 추가했다.
- context menu로 `글자 모양` 다이얼로그 값을 예약한 뒤 입력한 텍스트에 font size, bold, color 기본값이 적용되는 위젯 테스트를 추가했다.
- 전체 위젯 테스트 실행 중 드러난 긴 context menu/dialog 테스트의 viewport 보정, caret blink 대기 시간, table-cell search selection 기대값을 현재 native editor 동작에 맞게 정리했다.

## 이 작업을 진행한 이유

- Flutter-native 에디터를 WebView fallback과 별개로 실제 편집 surface로 키우려면, 선택 영역에만 서식을 적용하는 수준을 넘어 caret 위치에서 다음 입력 서식을 예약할 수 있어야 한다.
- 기존 `_applyCharFormat` 경로는 collapsed caret의 pending format을 이미 지원했지만, context menu가 선택 영역이 없으면 문자 서식 항목을 막고 있어 사용자가 우클릭 메뉴에서 이 기능을 사용할 수 없었다.
- upstream 웹 에디터처럼 caret 기반 편집 흐름을 만들려면 toolbar, shortcut, context menu가 같은 편집 모델을 공유해야 한다.

## 이 작업을 통해 배울점

- UI enable 조건은 command 구현 여부와 맞춰야 한다. 내부 편집 API가 collapsed caret을 처리해도, 메뉴가 selection 기반으로 막고 있으면 기능은 사용자에게 도달하지 않는다.
- Flutter-native 에디터 테스트는 toolbar와 popup menu가 스크롤 가능한 surface 안에 있으므로, 긴 메뉴나 다이얼로그를 검증할 때 테스트 viewport와 `ensureVisible` 처리가 중요하다.
- table-cell search는 body search와 마찬가지로 match range를 selection으로 유지하는 것이 자연스럽다. 테스트 기대값도 caret-only 상태가 아니라 active selection range를 기준으로 잡아야 한다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu applies pending character format to input"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu character shape sets pending format at caret"`
- `flutter test test/rhwp_widget_test.dart`
