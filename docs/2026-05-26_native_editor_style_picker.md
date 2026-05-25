# 2026-05-26 native editor style picker

## 작업한 내용

- rhwp core의 스타일 목록 조회와 스타일 적용 API를 Rust command envelope에 연결했다.
- Dart 문서 API에 `RhwpStyleInfo`, `styleList()`, `applyStyle()`, `applyCellStyle()`를 추가했다.
- Flutter-native editor의 `서식` 탭에 스타일 picker 버튼을 추가했다.
- picker에서 선택한 스타일을 본문 문단 범위 또는 선택된 표 셀 문단에 적용하도록 했다.
- Dart command serialization, widget flow, Rust facade 테스트를 추가했다.

## 이 작업을 진행한 이유

WebView 기반 full editor에는 문서 스타일 적용 UI가 있지만 Flutter-native editor에는 아직 없었다. 스타일은 문단 모양과 글자 모양을 묶어 문서 전체의 일관된 서식을 적용하는 기능이라, native editor가 실제 편집기로 성장하려면 toolbar에서 직접 다룰 수 있어야 한다.

이번 작업은 JS editor를 호출하지 않고 FRB/Rust command 경로로 스타일을 적용한다. WebView fallback은 그대로 두면서 Flutter 위젯 editor가 upstream editor 기능을 하나씩 흡수하는 방향에 맞다.

## 이 작업을 통해 배울 점

- upstream WASM API가 이미 제공하는 기능은 JS bridge로 우회하지 말고 Rust facade command로 노출하는 편이 플랫폼 공통성에 유리하다.
- 스타일 목록은 문서별 데이터이므로 editor 초기화 때 무조건 읽기보다 사용자가 picker를 열 때 lazy load하는 편이 테스트와 성능에 안정적이다.
- 표 셀 편집은 본문 문단과 다른 command를 써야 하므로, UI는 하나여도 적용 대상에 따라 Rust command를 분기해야 한다.

## 검증

- `flutter test test/flutter_rhwp_test.dart`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies document styles to paragraphs"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies document styles to table cells"`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`
