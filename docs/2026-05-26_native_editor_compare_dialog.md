# 2026-05-26 Native Editor Compare Dialog

## 작업한 내용

- Flutter-native editor의 `도구 > 검토` 리본에 있던 비활성 Compare 버튼을 동작하도록 연결했다.
- 현재 문서 텍스트는 `RhwpDocument.extractText()`로 가져오고, 사용자가 붙여 넣은 비교 텍스트와 line 단위로 비교한다.
- 비교 결과는 same, changed, added, removed 카운트와 preview list로 표시한다.
- 이 기능은 검토용 UI라서 HWP 문서 command를 실행하지 않고, 문서 내용이나 export 결과를 변경하지 않는다.
- README와 CHANGELOG에 native editor compare 기능을 반영했다.

## 이 작업을 진행한 이유

Flutter-native editor는 WebView fallback 없이도 검색, 검토, 보조 보기 같은 편집기 주변 기능을 제공해야 한다. Compare 버튼은 이미 toolbar에 자리만 잡혀 있었지만 비활성 상태였기 때문에, Rust core의 텍스트 추출 API를 사용해 실제 사용 가능한 검토 기능으로 전환했다.

## 이 작업을 통해 배울점

- 모든 editor 기능이 문서 mutation command일 필요는 없다. 검토/비교 기능은 Rust core에서 추출한 document state를 Flutter UI에서 해석하는 방식으로도 구현할 수 있다.
- Flutter-native editor 포팅은 toolbar 버튼을 단순히 노출하는 것이 아니라, 각 버튼이 문서 세션 API와 연결된 실제 workflow를 가져야 한다.
- line 기반 compare는 1차 구현으로 충분히 작고 검증 가능하지만, upstream 수준으로 가려면 이후 paragraph/run 단위 diff와 선택 영역 하이라이트로 확장할 수 있다.
