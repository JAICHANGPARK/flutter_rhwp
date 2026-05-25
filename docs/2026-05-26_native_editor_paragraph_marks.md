# 2026-05-26 Native Editor Paragraph Marks

## 작업한 내용

- Flutter-native editor의 `보기` 리본에 문단부호 토글을 추가했다.
- 토글이 켜지면 `pageLayerTree`의 텍스트 런을 paragraph 단위로 묶고, 각 paragraph의 마지막 런 끝 위치에 `¶` overlay를 표시한다.
- 이 표시는 Flutter overlay에서만 처리되며, Rust 렌더 결과나 HWP/HWPX/PDF export 결과는 변경하지 않는다.
- README와 CHANGELOG에 보기 옵션 확장 내용을 반영했다.

## 이 작업을 진행한 이유

upstream web editor에는 문단부호 같은 보기 옵션이 있으며, Flutter-native editor도 단순 command surface를 넘어 실제 문서 편집기처럼 보조 표시 레이어를 가져야 한다. 문단부호는 문서 모델을 수정하지 않으면서 page layer tree, overlay, toolbar state를 연결하는 기능이라 WebView 의존을 줄이는 다음 단계로 적절하다.

## 이 작업을 통해 배울점

- HWP 문서의 보기 옵션은 렌더 산출물을 바꾸기보다 editor overlay에서 처리하는 것이 안전하다.
- page layer tree에 포함된 `stableSourceKey`와 UTF-16 범위를 활용하면 Rust core를 source of truth로 유지하면서 Flutter에서 편집기용 보조 UI를 만들 수 있다.
- Flutter-native editor 포팅은 웹 DOM 코드를 그대로 옮기는 방식이 아니라, 동일한 문서 상태를 Flutter 위젯/overlay/toolbar 구조로 재구성하는 작업이다.
