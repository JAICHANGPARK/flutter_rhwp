# Native editor viewer cursor refresh scope

## 작업한 내용

- `RhwpViewer`가 연결된 컨트롤러의 모든 알림에 반응해 rebuild하던 흐름을 줄였다.
- 이제 뷰어는 컨트롤러 알림 중 실제 `zoom` 값이 바뀐 경우에만 레이아웃을 다시 build한다.
- `RhwpEditorController.cursor` 변경만으로는 페이지 overlay builder가 다시 호출되지 않는 위젯 테스트를 추가했다.
- `CHANGELOG.md`와 `README.md`에 입력 중 페이지 표면 refresh를 줄인 내용을 반영했다.

## 이 작업을 진행한 이유

네이티브 에디터에서 Space나 텍스트 입력을 할 때 커서 위치가 매번 갱신된다. 기존 구조에서는 커서 변경도 `RhwpViewer`의 컨트롤러 알림으로 들어와 뷰어 전체가 다시 build되었고, 실제 SVG 재렌더는 지연되어도 화면이 refresh되는 것처럼 보일 수 있었다. 커서/선택 상태는 에디터 overlay와 pending text notifier가 처리하고, 뷰어 레이아웃은 줌 변화에만 반응하도록 역할을 나누기 위해 수정했다.

## 이 작업을 통해 배울 점

- 하나의 `ChangeNotifier`를 여러 위젯이 공유할 때, 알림의 의미를 구분하지 않으면 필요 없는 rebuild가 쉽게 발생한다.
- 문서 편집기처럼 입력 빈도가 높은 화면에서는 “문서 명령 실행”, “커서 overlay 갱신”, “페이지 SVG 재렌더”를 분리해야 입력 체감이 안정적이다.
- 테스트는 실제 렌더 결과뿐 아니라 overlay builder 호출 횟수처럼 rebuild 범위를 검증하는 방식도 필요하다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer ignores editor cursor notifications for page rebuilds"`는 현재 샌드박스가 Flutter test의 `127.0.0.1:0` 서버 소켓 생성을 막아 실행하지 못했다.
