# 2026-06-02 native editor position field navigation

## 작업한 내용

Flutter-native editor의 `Sec` / `Para` / `Offset` 입력 필드 옆에 위치 이동 버튼을 추가했다.
버튼을 누르면 입력된 문서 위치를 `RhwpCursorPosition`으로 해석하고, rhwp core의
`getPageOfPosition` 경로를 통해 해당 문단이 속한 페이지를 계산한 뒤 커서와 페이지 뷰포트를
같이 이동한다.

위치 이동 중에는 표 셀 선택 상태를 해제하고 본문 커서를 갱신한다. 이동이 끝난 뒤에는 편집기
포커스를 복원해 바로 입력을 이어갈 수 있게 했다.

## 이 작업을 진행한 이유

상태바와 리본에 표시되는 `Sec` / `Para` / `Offset` 값은 현재 커서 위치를 보여주는 역할만
하고 있었다. 실제 HWP 편집기처럼 위치 값을 기준으로 문서 내부 특정 지점으로 이동하려면
해당 필드가 명령 입력으로도 동작해야 한다.

Flutter-native editor를 100% Flutter UI로 포팅하려면 WebView editor의 보조 탐색 기능을
하나씩 대체해야 한다. 이번 작업은 문서 위치 기반 탐색을 Flutter 위젯과 Rust core 명령으로
연결한 작은 단위다.

## 이 작업을 통해 배울점

문서 위치 이동은 단순히 커서 좌표만 바꾸면 안 된다. 긴 문서에서는 입력한 문단이 다른 페이지에
있을 수 있으므로 core가 제공하는 위치-페이지 매핑을 거쳐야 한다.

또한 표 셀 선택, 본문 커서, 페이지 스크롤, 포커스 복원은 서로 다른 UI 상태지만 하나의 사용자
동작으로 함께 정리되어야 한다. 이렇게 해야 위치 이동 후 바로 타이핑해도 입력 대상이 흔들리지
않는다.

## 검증

다음 widget test를 추가해 위치 필드 입력, `getPageOfPosition` 호출, 커서 갱신, 페이지 상태바
갱신을 확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor jumps to cursor from position fields"
```
