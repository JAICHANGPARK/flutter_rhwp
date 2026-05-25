# 2026-05-26 Native Editor Context Status Bar

## 작업한 내용

- Flutter-native editor 상태바가 본문 커서뿐 아니라 표 셀과 object 선택 상태를 표시하도록 확장했다.
- 표 셀 선택 중에는 1-based row/column 범위 또는 active cell paragraph/offset을 보여준다.
- object 선택 중에는 object type, object index, page, control index를 보여준다.
- 상태바 위치 텍스트에 안정적인 widget key를 추가하고, 표 셀 선택/표 셀 텍스트 편집/object 선택 테스트에서 실제 표시 문자열을 검증했다.

## 이 작업을 진행한 이유

기존 상태바는 항상 `Sec / Para / Offset`만 보여줬다. 표 셀이나 object를 편집할 때 이 정보는 실제 사용자가 보고 싶은 위치 정보와 맞지 않는다. Flutter-native editor가 문서 편집기로 동작하려면 현재 선택 컨텍스트를 즉시 확인할 수 있어야 한다.

## 이 작업을 통해 배울점

- 상태바는 단순 보조 UI가 아니라 selection model이 올바르게 연결됐는지 확인하는 디버깅/사용성 표면이다.
- 표 셀은 내부 모델이 0-based여도 사용자-facing 표시는 1-based row/column으로 보여주는 편이 자연스럽다.
- object selection도 page layer tree에서 얻은 type/index/control 정보를 표시하면 object 편집 command가 어느 대상에 적용되는지 추적하기 쉽다.
