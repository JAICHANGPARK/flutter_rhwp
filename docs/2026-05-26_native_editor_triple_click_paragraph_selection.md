# 2026-05-26 native editor triple click paragraph selection

## 작업한 내용

- `RhwpNativeEditor` page overlay에서 primary pointer triple-click을 감지한다.
- triple-click 대상 text hit의 section/paragraph를 parent editor로 넘기고, parent editor가 문서 전체 page layer tree에서 해당 paragraph end offset을 찾도록 연결했다.
- paragraph 시작 offset 0부터 계산된 end offset까지 `RhwpSelectionRange`를 만들어 Flutter-native selection overlay에 반영한다.
- widget test로 같은 text run을 세 번 클릭했을 때 단어 선택을 넘어 전체 paragraph selection으로 확장되는지 검증했다.

## 이 작업을 진행한 이유

WebView 기반 upstream 에디터를 대체하려면 Flutter-native 에디터도 마우스 선택 UX를 단계적으로 갖춰야 한다. 더블클릭 단어 선택 다음 자연스러운 단계는 triple-click paragraph selection이며, 이후 copy/cut/paste, formatting, replace 동작이 paragraph 단위 selection을 그대로 재사용할 수 있다.

## 이 작업을 통해 배울 점

- overlay는 pointer sequence와 hit-test만 판단하고, 문서 전체를 봐야 하는 paragraph range 계산은 editor state가 처리하는 쪽이 책임 분리가 좋다.
- selection UX는 문서를 수정하지 않으므로 Rust edit command를 만들지 않고 controller state만 갱신해야 undo history를 오염시키지 않는다.
- Flutter-native 에디터의 입력 UX는 DOM 이벤트를 그대로 옮기는 작업이 아니라, Flutter pointer event와 rhwp page-layer source 위치를 연결하는 작업이다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor selects a paragraph on triple click"`
