# 2026-05-26 native editor pending character format

## 작업한 내용

- `RhwpNativeEditor`에서 선택 영역이 접힌 상태로 글자 서식 버튼, 글자 크기, 텍스트 색상을 누르면 pending character format 상태로 저장되도록 했다.
- 이후 본문 텍스트가 입력되면 `insertText` 직후 같은 edit transaction 안에서 방금 삽입한 범위에 `applyCharFormatRange`를 적용한다.
- Bold/Italic/Underline/Strike 버튼은 pending 상태에서 다시 누르면 토글된다.
- 서식 버튼은 pending 상태를 시각적으로 표시하도록 선택 스타일을 추가했다.

## 이 작업을 진행한 이유

실제 문서 편집기는 텍스트를 먼저 선택하지 않아도 서식을 켜고 다음에 입력하는 글자에 적용할 수 있어야 한다. 기존 Flutter-native editor는 collapsed selection에서 서식 명령을 무시했기 때문에 WebView fallback을 대체하기에는 입력 UX가 부족했다.

Rust core의 `insertText` command는 글자 모양 payload를 직접 받지 않으므로, Flutter 쪽에서 pending 상태를 유지하고 삽입 직후 해당 범위에 기존 `applyCharFormatRange` command를 붙이는 방식으로 구현했다.

## 이 작업을 통해 배울 점

- Flutter-native editor는 문서 모델 command뿐 아니라 편집기의 transient state도 가져야 한다.
- collapsed selection의 서식 상태는 문서를 즉시 수정하지 않지만, 다음 입력 command와 결합되어야 실제 에디터처럼 동작한다.
- Rust command 계약을 크게 늘리기 전에 기존 command 조합으로 UX를 구현할 수 있는지 먼저 확인하는 편이 안전하다.

## 검증

- `RhwpNativeEditor applies pending character format to input` 위젯 테스트를 추가했다.
- 테스트는 collapsed selection에서 Bold, `14.5pt`, 파란색을 선택한 뒤 `Z`를 입력하면 `insertText` 다음에 같은 범위로 `applyCharFormatRange`가 발생하는지 확인한다.

