# 2026-05-26 native editor alignment shortcuts

## 작업한 내용

- `RhwpNativeEditor`에 Ctrl/Cmd+L/E/R/J 단축키를 추가했다.
- 각 단축키는 Flutter-native toolbar와 같은 `applyParaFormatRange` 경로를 사용한다.
- 선택 영역이 있으면 선택된 문단 범위에, 선택이 접혀 있으면 현재 caret 문단에 left, center, right, justify 정렬을 적용한다.
- 단축키별 command envelope를 확인하는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

Flutter 위젯 에디터가 WebView fallback을 대체하려면 버튼만 있는 command editor가 아니라 실제 문서 편집기처럼 키보드 중심 작업을 지원해야 한다. 정렬은 한글/워드프로세서 편집에서 자주 쓰는 기능이고, 이미 Rust command와 toolbar 경로가 있으므로 단축키를 붙이면 native editor의 실사용성이 바로 올라간다.

## 이 작업을 통해 배울 점

- Web editor의 기능을 Flutter로 옮길 때는 새 command를 만들기보다 기존 command 경로를 재사용하는 편이 안전하다.
- 단축키는 UI 버튼과 같은 내부 함수를 호출해야 undo/redo, refresh, selection 유지 정책이 일관된다.
- 플랫폼별 Ctrl/Cmd 차이는 Flutter의 `HardwareKeyboard` 상태를 통해 공통 처리할 수 있다.

## 검증

- `RhwpNativeEditor applies paragraph alignment shortcuts` 위젯 테스트를 추가했다.
- 테스트는 Ctrl+L/E/R/J가 각각 left, center, right, justify `applyParaFormatRange` command를 생성하는지 확인한다.
