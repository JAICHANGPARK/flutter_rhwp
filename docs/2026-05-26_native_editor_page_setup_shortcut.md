# 2026-05-26 native editor page setup shortcut

## 작업한 내용

- Flutter-native editor에서 `F7`을 누르면 page setup dialog가 열리도록 했다.
- 기존 page ribbon의 `Page setup` 버튼과 같은 Rust page setup query/update 경로를 재사용했다.
- `F7` shortcut widget test와 README, CHANGELOG를 추가했다.

## 이 작업을 진행한 이유

upstream rhwp 웹 에디터 메뉴에는 `편집 용지 F7` 단축키가 있다. Flutter-native editor에도 page setup dialog는 이미 있었지만, keyboard workflow는 아직 부족했다. WebView editor를 열지 않고도 실제 HWP 편집기에서 기대하는 페이지 설정 진입 흐름을 Flutter widget surface에서 제공하기 위해 연결했다.

## 이 작업을 통해 배울 점

- Flutter-native 포팅은 화면 버튼만 맞추는 것이 아니라 upstream editor의 keyboard workflow까지 맞춰야 한다.
- 이미 구현된 dialog/command가 있으면 shortcut만 연결해도 WebView fallback 의존도를 줄일 수 있다.
- page setup 같은 문서 전역 기능은 UI focus가 문서 surface에 있을 때 바로 접근 가능해야 편집 흐름이 끊기지 않는다.
