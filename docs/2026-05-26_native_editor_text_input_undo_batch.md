# 2026-05-26 native editor text input undo batch

## 작업한 내용

- Flutter-native editor에서 연속 텍스트 입력을 하나의 undo snapshot batch로 묶었다.
- 첫 글자 입력 때만 `saveSnapshot`을 만들고, 같은 pending text refresh 구간의 다음 글자는 기존 snapshot을 재사용하도록 했다.
- deferred page refresh가 실제로 flush되거나 취소되면 text-input undo batch를 닫도록 정리했다.
- 빠른 연속 입력 테스트에 `saveSnapshot`이 한 번만 호출되는 검증을 추가했다.

## 이 작업을 진행한 이유

큰 HWP 문서에서는 글자나 스페이스 입력마다 전체 문서 snapshot을 다시 만들면 입력이 멈칫하거나 화면이 refresh되는 것처럼 보일 수 있다. 문서 모델에는 각 글자 입력 명령을 즉시 반영하되, undo 기준점은 사용자가 이어서 타이핑하는 동안 하나로 유지하는 편이 일반적인 에디터 UX와도 맞다.

## 이 작업을 통해 배울 점

- 편집 명령의 적용 단위와 undo snapshot 단위는 분리할 수 있다.
- 대형 문서 에디터에서는 렌더 refresh뿐 아니라 undo/history 비용도 입력 체감 성능에 직접 영향을 준다.
- TextInput 기반 입력은 pending refresh 구간을 하나의 타이핑 세션으로 보고 batch 처리하는 구조가 필요하다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor queues rapid text input commits"`
