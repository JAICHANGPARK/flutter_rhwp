# 2026-05-26 native editor table cell search replace

## 작업한 내용

- `RhwpNativeEditor`의 찾기/바꾸기 대상에 표 셀 text run을 포함했다.
- 검색 match에 표 control index, cell index, cell paragraph, 셀 행/열 범위를 저장해 active match가 표 셀 안에 있을 때 셀 선택 상태로 이동하도록 했다.
- 검색 highlight는 body text와 table cell text를 구분해서 그리도록 바꿨다. 같은 paragraph offset을 쓰는 다른 셀을 잘못 highlight하지 않도록 `cellContext`를 확인한다.
- active match 바꾸기는 표 셀 match일 때 `deleteTextInTableCell`과 `insertTextInTableCell` command를 사용한다.
- 검색 중 표 셀 match를 선택해도 toolbar가 자동으로 table tab으로 전환되지 않고 tools tab을 유지하도록 했다.

## 이 작업을 진행한 이유

WebView를 쓰지 않는 Flutter-native editor가 실제 문서 편집기로 동작하려면 본문뿐 아니라 표 안의 텍스트도 찾기/바꾸기 대상이어야 한다. 기존 구현은 `cellContext`가 있는 text run을 검색에서 제외해서, 표가 많은 HWP 문서에서는 검색 기능이 중요한 내용을 놓칠 수 있었다.

upstream 웹 에디터는 브라우저 이벤트와 WASM layout 정보를 묶어서 표 내부 텍스트까지 편집 대상으로 다룬다. Flutter-native 쪽에서는 같은 역할을 page layer tree의 `cellContext`와 Rust bridge table-cell command로 재구성해야 한다.

## 이 작업을 통해 배울 점

- 표 셀 text run은 본문 paragraph와 같은 숫자 offset을 가질 수 있으므로 검색 highlight와 replace target을 `section/paragraph/offset`만으로 식별하면 부족하다.
- 검색 match 모델에 cell context를 포함하면 selection, highlight, replace command를 같은 데이터에서 안정적으로 만들 수 있다.
- 검색 UX 중에는 표 셀 선택이 발생해도 도구 탭을 유지해야 검색 결과 count, 이전/다음, 바꾸기 컨트롤이 사라지지 않는다.

## 검증

- `RhwpNativeEditor finds text inside table cells` 위젯 테스트를 추가했다.
- `RhwpNativeEditor replaces the active table cell search match` 위젯 테스트를 추가했다.
- 기존 body text 검색, active replace, replace-all 테스트도 함께 통과하는지 확인했다.
