# 2026-05-25 native editor word delete

## 작업한 내용

- `RhwpNativeEditor`에서 Ctrl/Option+Backspace와 Ctrl/Option+Delete 단어 단위 삭제를 추가했다.
- 삭제 범위는 기존 word navigation과 같은 paragraph text 복원 및 separator 규칙을 사용한다.
- 선택 영역이 있는 경우에는 단어 계산보다 selection 삭제를 우선 처리한다.
- table cell 편집 상태에서는 기존 cell text 단일 문자 삭제 fallback을 유지했다.
- widget test로 Option+Backspace, Ctrl+Delete, 선택 영역 우선 삭제를 검증했다.

## 이 작업을 진행한 이유

- 문서 편집기에서 단어 단위 이동과 단어 단위 삭제는 함께 기대되는 기본 입력 UX다.
- Flutter-native 에디터가 WebView 의존도를 줄이려면 keyboard editing 동작을 Flutter surface에서 직접 처리해야 한다.
- 기존 word navigation helper를 재사용하면 단어 이동과 삭제가 같은 경계 규칙을 공유한다.

## 이 작업을 통해 배울점

- 편집 command는 navigation과 달리 `deleteText` Rust command와 change callback이 정확히 발생해야 한다.
- 선택 영역이 있을 때는 modifier 삭제라도 선택 영역 삭제가 우선되어야 일반 텍스트 편집기와 일관된다.
- 단어 삭제는 문서를 수정하므로 command/history 테스트와 cursor 위치 검증을 같이 두는 편이 안전하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor deletes by word with keyboard modifiers"`
