# Native Editor Table Formula

## 작업한 내용

- `RhwpCommand.evaluateTableFormula`와 `RhwpDocument.evaluateTableFormula`를 추가했다.
- Rust FRB command bridge에서 rhwp core의 `evaluate_table_formula`를 호출하도록 연결했다.
- `RhwpNativeEditor` 표 리본에 계산식 입력 필드와 실행 버튼을 추가했다.
- 선택된 활성 표 셀의 row/column을 page layer tree에서 찾아 계산식 결과를 해당 셀에 기록하도록 했다.
- Dart API 테스트, Flutter 위젯 테스트, Rust command 테스트를 추가했다.

## 이 작업을 진행한 이유

Flutter-native editor가 WebView fallback을 대체하려면 표 편집도 단순 행/열 조작을 넘어 실제 문서 편집 기능을 가져야 한다. rhwp core에는 이미 표 계산식 평가 API가 있으므로 JS editor를 호출하지 않고 FRB를 통해 직접 노출하는 것이 native editor 방향에 맞다.

## 이 작업을 통해 배울 점

- Flutter editor UI는 명령 입력만 담당하고, 계산식 평가와 문서 변경은 Rust core를 source of truth로 둔다.
- 표 셀의 표시 좌표와 모델 셀 인덱스는 page layer tree를 통해 연결해야 한다.
- Web editor 기능을 Flutter로 옮길 때는 JS를 감싸기보다 core API를 하나씩 공개하고 테스트로 command envelope를 고정하는 편이 유지보수에 유리하다.
