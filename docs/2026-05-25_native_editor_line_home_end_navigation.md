# 2026-05-25 native editor line home end navigation

## 작업한 내용

- `RhwpNativeEditor`의 Home/End 키를 page layer tree의 현재 text run 시작/끝으로 이동하도록 개선했다.
- 현재 caret이 포함된 text run을 찾으면 Home은 run `charStart`, End는 run `charEnd`로 이동한다.
- text run geometry를 찾지 못하면 기존처럼 Home은 paragraph offset `0`, End는 paragraph 끝 위치로 fallback한다.
- Shift+Home/End는 기존 selection anchor를 유지한 채 현재 렌더링 줄 시작/끝까지 선택을 확장한다.
- widget test fixture가 한 paragraph를 두 text run으로 나눌 수 있도록 source char offset 파라미터를 추가했다.

## 이 작업을 진행한 이유

- 실제 WYSIWYG 편집기에서 Home/End는 문단 전체가 아니라 현재 화면 줄 기준으로 동작한다.
- Flutter-native 에디터가 upstream Web editor를 대체하려면 caret movement도 렌더링 geometry를 기준으로 맞춰가야 한다.
- geometry fallback을 유지하면 page layer tree가 부족한 문서에서도 기존 동작을 잃지 않는다.

## 이 작업을 통해 배울점

- 같은 paragraph라도 렌더링 결과에서는 여러 줄/text run으로 분리될 수 있으므로 keyboard navigation은 source position과 layout position을 함께 봐야 한다.
- Home/End, ArrowUp/Down 모두 page layer tree의 text run geometry를 공유할수록 Flutter-native editor의 UX가 일관된다.
- 테스트 fixture에 source char offset을 명시할 수 있어야 같은 paragraph 내 multi-line 동작을 안정적으로 검증할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor uses page geometry for home and end"`
