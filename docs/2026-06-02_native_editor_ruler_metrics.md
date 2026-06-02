# 2026-06-02 native editor ruler metrics

## 작업한 내용

- Flutter-native ruler에 현재 문단의 왼쪽 여백, 첫 줄 들여쓰기, 오른쪽 여백 마커를 추가했다.
- 마커 위치는 이미 동기화 중인 `RhwpParaProperties`의 `marginLeft`, `indent`, `marginRight` 값을 사용한다.
- ruler 마커는 표시 전용 Flutter 위젯으로 구현해 문서 수정 명령이나 저장 상태를 만들지 않도록 했다.
- widget test로 ruler 토글 후 세 마커가 표시되고, zoom 변경 시 마커 위치가 다시 계산되는지 검증했다.

## 이 작업을 진행한 이유

기존 ruler는 눈금만 표시해서 upstream rhwp 웹 에디터의 편집 chrome을 대체하기에는 정보가 부족했다. Flutter-native editor를 WebView fallback과 별도 surface로 키우려면 현재 caret 문단의 레이아웃 상태가 toolbar/ruler에 즉시 반영되어야 한다.

## 이 작업을 통해 배울점

- Flutter-native editor UI는 Rust 문서 상태를 새로 조회하기보다 이미 동기화 중인 상태 모델을 재사용하는 편이 안정적이다.
- ruler처럼 문서 내용을 바꾸지 않는 chrome 기능은 command path와 분리해야 refresh, undo, dirty 상태가 불필요하게 흔들리지 않는다.
- CustomPaint만 쓰면 테스트에서 상태를 직접 확인하기 어렵기 때문에 중요한 편집 chrome 요소는 key가 있는 Flutter 위젯으로 표현하는 것이 낫다.

## 검증

- `flutter test test/rhwp_widget_test.dart --name "ruler"`
