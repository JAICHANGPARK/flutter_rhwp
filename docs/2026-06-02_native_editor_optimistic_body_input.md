# 2026-06-02 Native Editor Optimistic Body Input

## 작업한 내용

- Flutter-native editor에서 collapsed body text 입력은 Rust `insertText` command 완료를 기다리지 않고 pending text overlay와 caret를 먼저 갱신하도록 변경했다.
- 느린 `insertText` command가 진행 중이어도 이어지는 Space/문자 입력은 현재 Flutter caret 위치를 기준으로 overlay에 누적되도록 했다.
- Rust command는 큐에 남겨서 원본 document에는 순서대로 반영하고, page SVG refresh는 기존처럼 text input이 끝날 때까지 보류한다.
- 느린 insert command 중 Space 다음 문자 입력이 보이고, refresh/render가 발생하지 않는 widget test를 추가했다.

## 이 작업을 진행한 이유

- 큰 HWP 문서에서는 Rust command 자체가 즉시 끝나지 않을 수 있고, 이때 pending overlay가 command 완료 후에야 보이면 사용자는 입력마다 화면이 멈추거나 refresh되는 것처럼 느낀다.
- WebView fallback 없이 Flutter-native editor를 실제 편집기로 쓰려면 키 입력 직후의 시각 피드백은 Flutter 위젯 레이어에서 먼저 처리해야 한다.
- 이번 변경은 문서 저장/동기화는 Rust core에 맡기면서도 입력 UX는 Flutter가 즉시 반응하도록 분리하는 단계다.

## 이 작업을 통해 배울점

- Flutter-native editor에서 render refresh 지연만으로는 충분하지 않고, 느린 command 중에도 caret와 pending text가 독립적으로 움직여야 한다.
- command 큐의 원본 cursor와 화면의 optimistic cursor를 분리해야 빠른 연속 입력의 offset이 틀어지지 않는다.
- 선택 삭제, overwrite, table-cell 입력처럼 source context가 복잡한 경로는 별도 optimistic 정책이 필요하므로 우선 collapsed body 입력부터 좁게 적용하는 것이 안전하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "previews rapid text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "rapid text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "text input"`
- `flutter analyze`
- `git diff --check`
