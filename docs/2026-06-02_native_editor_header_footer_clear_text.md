# 2026-06-02 Native Editor Header Footer Clear Text

## 작업한 내용

- Flutter-native editor의 쪽 리본에 머리말 텍스트 비우기와 꼬리말 텍스트 비우기 버튼을 추가했다.
- 버튼 동작은 `getHeaderFooter`로 현재 컨트롤과 텍스트 길이를 확인한 뒤 `deleteTextInHeaderFooter`를 호출하도록 연결했다.
- 텍스트가 없거나 컨트롤이 없으면 edit snapshot을 만들지 않고 그대로 종료하도록 했다.
- header와 footer 각각의 삭제 명령이 올바른 `isHeader` 값으로 내려가는 widget test를 추가했다.

## 이 작업을 진행한 이유

기존 Flutter-native page ribbon은 머리말/꼬리말 생성, 텍스트 삽입, 목록에서 컨트롤 삭제는 제공했지만 텍스트만 바로 비우는 동작은 다이얼로그의 대체 흐름 안에 숨어 있었다.

WebView 기반 full editor를 대체하려면 자주 쓰는 문서 편집 작업을 Flutter 위젯 리본에서 직접 실행할 수 있어야 한다. 텍스트만 비우는 버튼을 별도로 노출하면 컨트롤 자체를 삭제하지 않고 머리말/꼬리말 내용을 빠르게 초기화할 수 있다.

## 이 작업을 통해 배울점

- 머리말/꼬리말 컨트롤 삭제와 텍스트 삭제는 다른 명령이다. 전자는 `deleteHeaderFooter`, 후자는 `deleteTextInHeaderFooter`다.
- 텍스트 삭제는 현재 텍스트 길이를 알아야 하므로 먼저 `getHeaderFooter`를 호출해 컨트롤 존재 여부와 텍스트 길이를 확인해야 한다.
- UI에서 명령을 직접 노출할 때는 텍스트가 없는 상태에서 불필요한 snapshot이나 변경 콜백이 생기지 않도록 no-op 경로를 분리하는 편이 안전하다.

## 검증

- `RhwpNativeEditor page ribbon clears header and footer text` 테스트에서 header와 footer 각각에 대해 `getHeaderFooter` 이후 `deleteTextInHeaderFooter`가 호출되는지 확인한다.
- 기존 page ribbon 머리말/꼬리말 생성, 텍스트 삽입, 컨트롤 삭제 테스트와 함께 실행해 기존 흐름과 충돌하지 않는지 확인한다.
