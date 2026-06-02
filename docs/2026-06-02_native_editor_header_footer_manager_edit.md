# 2026-06-02 Native Editor Header Footer Manager Edit

## 작업한 내용

- Flutter-native editor의 머리말/꼬리말 관리 다이얼로그에 선택 항목 텍스트 편집 버튼을 추가했다.
- 기존 머리말/꼬리말 텍스트 편집 흐름을 helper로 분리해 리본 버튼과 관리 다이얼로그가 같은 명령 경로를 사용하도록 했다.
- 선택한 관리 항목의 `section`, `isHeader`, `applyTo` 값을 그대로 사용해 `getHeaderFooter`, `deleteTextInHeaderFooter`, `insertTextInHeaderFooter` 명령을 실행하도록 연결했다.
- 선택한 꼬리말 항목을 manager에서 바로 편집하는 widget test를 추가했다.

## 이 작업을 진행한 이유

기존 Flutter-native page ribbon은 머리말/꼬리말 목록에서 항목을 삭제할 수 있었지만, 선택한 항목을 바로 편집하려면 별도 텍스트 버튼으로 돌아가야 했다.

WebView 기반 full editor를 대체하려면 관리 다이얼로그 안에서 목록 선택, 편집, 삭제 같은 문서 구조 작업이 끊기지 않아야 한다. 이 변경은 머리말/꼬리말 관리 표면을 Flutter 위젯만으로 조금 더 완결된 흐름으로 만든다.

## 이 작업을 통해 배울점

- manager에서 선택한 항목은 리본의 현재 section 값보다 더 구체적인 `section/isHeader/applyTo` 컨텍스트를 가진다.
- 같은 편집 명령을 여러 UI에서 호출할 때는 helper로 묶어 명령 순서와 snapshot 동작을 일관되게 유지하는 편이 안전하다.
- 목록 관리 UI는 삭제뿐 아니라 선택 항목의 후속 편집까지 이어져야 WebView fallback 없이 실제 편집기로 느껴진다.

## 검증

- `RhwpNativeEditor manager edits selected header footer text` 테스트에서 선택한 footer 항목의 텍스트 편집 명령이 `isHeader: false`로 내려가는지 확인한다.
- 기존 `page ribbon` 테스트 묶음으로 생성, 삽입, 대체, 비우기, 삭제 흐름과 충돌하지 않는지 확인한다.
