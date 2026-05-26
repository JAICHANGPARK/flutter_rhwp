# 2026-05-26 native editor alt t paragraph shape

## 작업한 내용

- Flutter-native editor에서 `Alt+T`를 누르면 문단 모양 dialog가 열리도록 했다.
- 기존 서식 리본의 문단 모양 dialog와 같은 Flutter widget/Rust command 경로를 재사용했다.
- 한글 입력 상태에서도 같은 물리 키 흐름을 받을 수 있도록 `T`, `t`, `ㅅ` 입력 문자를 함께 처리했다.
- `Alt+T` shortcut widget test와 README, CHANGELOG를 추가했다.

## 이 작업을 진행한 이유

upstream rhwp 웹 에디터 메뉴에는 `문단 모양 Alt+T` 단축키가 있다. Flutter-native editor가 WebView fallback을 줄이려면 버튼으로만 접근하는 기능을 넘어서 기존 HWP 사용자가 기대하는 단축키 흐름도 제공해야 한다.

## 이 작업을 통해 배울 점

- Flutter-native editor 포팅은 dialog나 command 구현 이후에도 keyboard entry point를 계속 맞춰야 한다.
- 같은 서식 기능이라도 글자 모양 `Alt+L`, 문단 모양 `Alt+T`처럼 조합별 의미를 분리해 처리해야 한다.
- 한글 IME 환경에서는 logical key와 character fallback을 함께 고려해야 shortcut이 안정적이다.
