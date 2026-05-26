# 2026-05-26 native editor para shape dialog prefill

## 작업한 내용

- Flutter-native editor의 `_CurrentParaFormat`에 indent, left/right margin, before/after spacing 상태를 추가했다.
- `문단 모양` dialog가 항상 기본값으로 열리지 않고, 현재 caret 또는 active table cell 문단의 alignment, line spacing, indent, margins, spacing 값을 초기값으로 사용하도록 변경했다.
- 현재 문단 속성으로 dialog field가 채워지는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

문단 속성을 적용하는 기능만으로는 WYSIWYG 편집 UX가 부족하다. 사용자가 문서 안의 문단에 커서를 둔 뒤 `문단 모양`을 열면, dialog가 실제 문단 상태를 보여줘야 한다.

이전 구현은 Rust core에서 현재 문단 속성을 조회할 수 있어도 dialog는 `justify`, `160`, `0`으로 시작했다. 이 작업은 Flutter UI가 Rust 문서 모델의 현재 상태를 더 직접적으로 반영하게 만든다.

## 이 작업을 통해 배울 점

- 리본 selected state와 dialog initial state는 같은 source of truth를 바라봐야 한다.
- 문단 속성은 alignment와 line spacing뿐 아니라 indent/margins/spacing까지 함께 보관해야 dialog UX가 자연스럽다.
- Flutter `TextEditingController`를 dialog state에서 초기화하면 현재 문단 상태를 안정적으로 field에 주입할 수 있다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor preloads paragraph shape dialog from caret"`
