# 2026-05-26 native editor replace shortcut

## 작업한 내용

- Flutter-native editor에서 `Ctrl/Cmd+H`를 누르면 tools ribbon을 열고 replace 입력창에 focus를 주도록 했다.
- replace 입력창에 별도 `FocusNode`를 연결해 단축키 재입력 시 기존 replace text가 전체 선택되도록 했다.
- replace focus가 editor 내부 focus로 처리되도록 desktop text refresh hold의 외부 focus 판정에 포함했다.
- replace shortcut widget test와 README, CHANGELOG를 추가했다.

## 이 작업을 진행한 이유

upstream web editor는 검색과 바꾸기 흐름을 tools 영역에서 직접 처리한다. Flutter-native editor에도 replace UI와 command는 있었지만, 문서에서 바로 바꾸기 작업으로 진입하는 keyboard path가 부족했다. WebView editor를 열지 않고도 자주 쓰는 편집 흐름을 Flutter widget surface 안에서 끝낼 수 있어야 한다.

## 이 작업을 통해 배울 점

- 편집기 포팅은 command 추가뿐 아니라 focus, shortcut, field selection 같은 작은 UX 경로까지 맞춰야 실제 에디터처럼 느껴진다.
- toolbar 입력 필드도 native editor 내부 focus로 분류해야 desktop text-input refresh hold와 충돌하지 않는다.
- 기존 replace command를 재사용하더라도 진입 단축키를 추가하면 WebView fallback 의존도를 줄일 수 있다.
