# 2026-05-26 native editor find focus selection

## 작업한 내용

- `Ctrl/Cmd+F`로 tools ribbon 검색창을 열 때 기존 검색어 전체를 선택하도록 했다.
- 기존 find shortcut 위젯 테스트를 확장해 검색어 입력 후 에디터로 돌아갔다가 다시 `Ctrl+F`를 눌렀을 때 검색창 focus와 전체 선택이 유지되는지 검증했다.
- README와 CHANGELOG에 검색창 focus/selection 동작을 반영했다.

## 이 작업을 진행한 이유

upstream `rhwp/web/editor.js`는 `Ctrl+F`에서 `searchInput.focus()`와 `searchInput.select()`를 함께 호출한다. Flutter-native editor도 같은 키보드 중심 검색 흐름을 제공해야 기존 검색어를 빠르게 바꿔 다시 검색할 수 있다.

버튼 중심 UI만 있으면 기능은 동작하지만, 실제 문서 편집기에서는 검색어를 수정하는 반복 작업이 잦다. 검색창 포커스와 전체 선택은 작지만 체감이 큰 editor parity 항목이다.

## 이 작업을 통해 배울 점

- upstream parity는 검색 실행뿐 아니라 focus와 selection 같은 입력 필드 상태까지 포함한다.
- Flutter에서는 `TextEditingController.selection`을 명시적으로 지정해 Web DOM의 `input.select()`와 같은 UX를 만들 수 있다.
- 검색창처럼 toolbar 내부 입력 필드도 문서 편집 workflow의 일부로 테스트해야 한다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor focuses search with find shortcut"`
- `flutter analyze`
