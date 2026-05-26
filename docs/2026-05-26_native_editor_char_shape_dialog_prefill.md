# 2026-05-26 native editor char shape dialog prefill

## 작업한 내용

- Flutter-native editor의 `글자 모양` dialog가 현재 caret 또는 선택 시작 위치의 character shape를 초기값으로 사용하도록 변경했다.
- dialog 초기 상태에 font family, font size, bold/italic/underline/strike, superscript/subscript, emboss/engrave, text color, background color를 반영했다.
- 현재 글자 속성으로 dialog field와 toggle이 채워지는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

리본에는 현재 글자 속성이 동기화되어 있어도, `글자 모양` dialog가 항상 기본값으로 열리면 사용자는 현재 문서 상태를 확인하거나 일부 속성만 수정하기 어렵다.

upstream web editor와 비슷한 WYSIWYG UX로 가려면 dialog도 Rust core에서 조회한 현재 글자 속성을 source of truth로 삼아야 한다. 이 작업은 Flutter-native editor가 단순 command sender가 아니라 문서 상태를 반영하는 편집 surface가 되도록 만드는 단계다.

## 이 작업을 통해 배울 점

- toolbar state와 dialog state는 같은 current character shape 모델에서 파생되어야 일관성이 유지된다.
- collapsed-selection pending format과 current caret format을 합쳐 dialog 초기값을 만들면, 다음 입력에 적용될 pending format도 자연스럽게 이어갈 수 있다.
- 글자 모양 dialog는 상호 배타적인 superscript/subscript, emboss/engrave 상태를 초기값부터 정확히 유지해야 한다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor preloads character shape dialog from caret"`
