# 2026-05-26 native editor file export shortcuts

## 작업한 내용

- `RhwpNativeEditor`에서 Ctrl/Cmd+Shift+S를 HWPX 저장 단축키로 연결했다.
- Ctrl/Cmd+P를 PDF export 단축키로 연결했다.
- 기존 Ctrl/Cmd+S는 HWP 저장으로 유지했다.
- 파일 리본 export 테스트에 HWP/HWPX/PDF 단축키 흐름을 추가했다.
- README와 CHANGELOG에 native editor 파일 export 단축키를 반영했다.

## 이 작업을 진행한 이유

WebView full editor를 fallback으로 유지하더라도 Flutter-native editor가 실제 편집기로 쓰이려면 파일 메뉴의 핵심 작업을 리본 버튼뿐 아니라 키보드로도 실행할 수 있어야 한다. 특히 HWP/HWPX 저장과 PDF 출력은 사용자가 반복적으로 쓰는 파일 작업이다.

## 이 작업을 통해 배울 점

- 파일 리본 동작과 키보드 단축키는 같은 export 경로를 공유해야 저장/다운로드 처리가 플랫폼별로 일관된다.
- Ctrl/Cmd+Shift 조합은 `HardwareKeyboard` 상태로 분기해서 기존 Ctrl/Cmd+S와 충돌 없이 확장할 수 있다.
- Flutter-native editor는 문서 명령뿐 아니라 데스크톱 앱다운 파일 작업 단축키까지 갖춰야 WebView 의존도를 줄일 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor file ribbon exports save artifacts"`
