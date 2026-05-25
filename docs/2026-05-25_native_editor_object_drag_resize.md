# 2026-05-25 native editor object drag resize

## 작업한 내용

- `RhwpNativeEditor`의 page overlay에서 선택된 개체에 8개 리사이즈 핸들을 표시하도록 했다.
- 선택 개체 내부를 드래그하면 개체 위치를 이동하고, 핸들을 드래그하면 개체 크기를 조정하도록 했다.
- 드래그 결과는 기존 `getObjectProperties`/`setObjectProperties` 브리지 명령을 사용해 rhwp core에 반영한다.
- layer tree의 page 좌표와 rhwp 속성 좌표 사이 비율을 계산해 현재 속성값 기준으로 위치/크기를 갱신한다.
- widget test로 개체 이동과 south-east 핸들 리사이즈가 올바른 command envelope를 만드는지 검증했다.
- 편집 후 전체 `RhwpViewer`를 새로 만들지 않고 render revision만 갱신하도록 바꿔 입력 중 스크롤 위치가 초기화되지 않게 했다.
- 새 SVG 렌더가 완료되기 전에는 직전 SVG를 계속 보여주도록 해 입력 중 페이지가 로딩 화면으로 깜빡이는 현상을 줄였다.

## 이 작업을 진행한 이유

upstream `web/text_selection.js`의 object selection은 파란 테두리와 8개 핸들을 그려 개체 편집 대상을 시각화한다. Flutter-native editor도 단순 선택/삭제/속성 다이얼로그에 머물면 실제 편집기 경험과 거리가 있으므로, WebView 없이도 마우스로 개체를 직접 조정하는 WYSIWYG 편집 동작을 추가했다.

## 배울점

- Flutter overlay는 DOM canvas 대신 `Stack`과 pointer event로 object selection affordance를 재구성할 수 있다.
- 미리보기 selection bounds는 Flutter 상태에서 즉시 갱신하고, 실제 문서 변경은 pointer-up 시점에 undo-aware edit command로 커밋하는 편이 자연스럽다.
- page-layer bounds와 rhwp object property 단위가 항상 같다고 가정하면 위험하므로, 현재 width/height 속성을 기준으로 delta 비율을 환산해야 한다.
- 문서 내용이 바뀔 때 전체 viewer key를 교체하면 렌더는 갱신되지만 scroll controller와 visible page state도 같이 사라진다. Flutter-native editor에서는 viewer identity는 유지하고 page render/layer tree만 무효화하는 구조가 더 맞다.
- page render Future를 교체하더라도 이전 SVG를 보존하면 사용자 입력 중 화면이 비는 시간을 줄일 수 있다.

## 검증

- `dart format --set-exit-if-changed lib/src/rhwp_editor.dart test/rhwp_widget_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor drags selected objects to update position"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor resizes selected objects from overlay handles"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor preserves viewport while editing"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer keeps previous SVG while refreshed render is pending"`
- `flutter analyze`
- `flutter test`
- `(cd example && flutter test)`
