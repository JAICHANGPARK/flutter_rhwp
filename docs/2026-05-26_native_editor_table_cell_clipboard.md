# 2026-05-26 native editor table cell clipboard

## 작업한 내용

- `RhwpNativeEditor`의 Ctrl/Cmd+C, Ctrl/Cmd+X, Ctrl/Cmd+V가 선택된 표 셀에서도 동작하도록 했다.
- 표 셀 복사는 page layer tree의 `cellContext`가 붙은 text run을 읽어 셀 텍스트를 clipboard에 넣는다.
- 표 셀 잘라내기는 같은 텍스트 run 범위를 `deleteTextInTableCell` command로 지운다.
- 표 셀 붙여넣기는 기존 `insertTextInTableCell` 경로를 재사용해 active cell offset에 clipboard text를 삽입한다.
- 이후 탭/줄바꿈이 들어 있는 clipboard text는 선택 셀을 기준으로 여러 셀에 분배해서 붙여넣도록 확장했다.
- 표 셀 context menu에서도 복사/잘라내기 항목이 활성화되도록 했다.

## 이 작업을 진행한 이유

Flutter-native editor는 이미 표 셀 선택, 셀 이동, 셀 텍스트 입력/삭제를 지원하지만 clipboard가 body selection에만 묶여 있었다. 실제 문서 편집기에서는 표 셀을 선택한 뒤 복사, 잘라내기, 붙여넣기가 자연스럽게 이어져야 한다.

WebView 에디터를 그대로 쓰지 않고 Flutter 위젯 에디터를 키우려면 표 편집도 toolbar command에 머물지 않고 키보드와 context menu 중심의 기본 편집 흐름까지 갖춰야 한다.

## 이 작업을 통해 배울 점

- 표 셀 편집은 body paragraph selection과 다른 source context를 가진다. `stableSourceKey`의 cell path와 layer tree의 `cellContext`를 사용해야 active cell text를 정확히 찾을 수 있다.
- clipboard, context menu, keyboard shortcut은 같은 내부 command 경로를 공유해야 기능별 동작 차이가 줄어든다.
- cell text 삭제는 DOM을 지우는 것이 아니라 rhwp core command인 `deleteTextInTableCell`을 사용해야 저장/export 결과와 일치한다.

## 검증

- `RhwpNativeEditor copies cuts and pastes selected table cell text` 위젯 테스트를 추가했다.
- 테스트는 선택된 표 셀의 `cell` 텍스트 복사, `deleteTextInTableCell` 기반 잘라내기, `insertTextInTableCell` 기반 붙여넣기 command를 검증한다.
