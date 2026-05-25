# 2026-05-26 native editor inline character toolbar

## 작업한 내용

- `RhwpNativeEditor`의 `서식` 리본에 글자 크기 입력 필드와 적용 버튼을 추가했다.
- 같은 리본에 검정, 빨강, 파랑, 초록 텍스트 색상 swatch 버튼을 추가했다.
- 글자 크기와 색상은 기존 `applyCharFormatRange` command를 사용해 선택 영역에 바로 적용된다.
- 글자 모양 dialog와 toolbar가 같은 pt to HWP base size 변환 로직과 색상 swatch 정의를 공유하도록 정리했다.

## 이 작업을 진행한 이유

WebView fallback 없이 Flutter 위젯 에디터를 실제 편집기처럼 쓰려면 자주 쓰는 서식 조작이 dialog 안에만 있으면 안 된다. upstream 웹 에디터와 한글 편집기형 UI는 툴바에서 글자 크기와 색상을 바로 바꾸는 흐름이 기본이므로, Flutter-native 리본도 이 조작을 노출해야 한다.

## 이 작업을 통해 배울 점

- Flutter-native 에디터는 Rust command surface를 재사용하되, 자주 쓰는 조작은 dialog보다 리본에 직접 노출하는 편이 편집 흐름에 맞다.
- UI 컨트롤과 dialog가 같은 값 변환 함수를 공유하면 pt 단위와 HWP 내부 단위가 엇갈리는 실수를 줄일 수 있다.
- 작은 toolbar 기능도 selection state, command serialization, render refresh까지 이어지는 end-to-end 테스트가 있어야 안정적으로 확장할 수 있다.

## 검증

- `RhwpNativeEditor applies inline character toolbar values` 위젯 테스트를 추가했다.
- 테스트는 글자 크기 `14.5pt`가 `fontSize: 1450` command로 나가고, 파란색 swatch가 `textColor: "#2563eb"` command로 나가는지 확인한다.

