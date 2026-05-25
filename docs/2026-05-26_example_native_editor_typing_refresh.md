# 2026-05-26 example native editor typing refresh

## 작업한 내용

- 예제 앱의 `RhwpNativeEditor.editRefreshDelay`를 1.2초에서 5초로 늘렸다.
- native editor에서 문서가 바뀔 때마다 `exportHwp()`로 전체 HWP snapshot을 다시 만들던 흐름을 제거했다.
- native editor 변경은 dirty 플래그로만 기록하고, 사용자가 저장/내보내기하거나 full editor로 전환할 때 최신 HWP bytes를 만들도록 바꿨다.
- README와 CHANGELOG에 예제 앱의 typing refresh 정책을 반영했다.

## 이 작업을 진행한 이유

첨부한 204쪽 HWP처럼 큰 문서는 SVG 렌더와 HWP export 비용이 크다. 텍스트나 스페이스를 입력할 때마다 짧은 delay 뒤에 렌더 동기화와 HWP snapshot export가 이어지면, 사용자는 입력할 때마다 화면이 refresh되는 것처럼 느낄 수 있다.

문서 core에는 입력 명령을 즉시 반영하되, 무거운 화면 동기화와 snapshot 생성은 사용자가 잠깐 멈추거나 저장/모드 전환을 할 때 처리하는 편이 예제 앱 사용감에 맞다.

## 이 작업을 통해 배울 점

- 편집 명령 적용, 페이지 SVG 동기화, 파일 snapshot export는 같은 타이밍에 묶지 않는 것이 좋다.
- 큰 문서 예제에서는 실시간 저장보다 lazy export가 더 자연스럽다.
- full editor와 native editor를 함께 제공할 때는 모드 전환 시점에 최신 bytes를 만드는 방식이 불필요한 반복 export를 줄인다.

## 검증

- `flutter test example/test/widget_test.dart`
- `flutter analyze`
