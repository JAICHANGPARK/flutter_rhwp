# 2026-06-02 Native Editor Context Indent

## 작업한 내용

- Flutter-native 에디터의 본문 context menu에 `들여쓰기 줄이기`, `들여쓰기 늘리기` 항목을 추가했다.
- 표 셀 텍스트 편집 context menu에도 같은 들여쓰기 항목을 추가했다.
- toolbar에서 쓰던 paragraph indent step을 context menu에서도 재사용하도록 async helper를 분리했다.
- 본문 다중 문단 선택과 표 셀 active paragraph에 대한 command payload 테스트를 추가했다.

## 이 작업을 진행한 이유

- upstream web editor의 서식 툴바 기능을 Flutter-native editor에서 실제 편집 흐름에 맞게 확장하려면 toolbar뿐 아니라 context menu에서도 자주 쓰는 문단 서식을 다룰 수 있어야 한다.
- 들여쓰기는 문단 모양 다이얼로그를 열지 않고 즉시 적용하는 사용 빈도 높은 작업이다.
- body 문단과 표 셀 내부 문단은 같은 UI를 쓰더라도 command target이 달라 회귀 테스트가 필요하다.

## 이 작업을 통해 배울점

- toolbar 전용 `VoidCallback`은 유지하되 내부 적용 로직을 `Future<void>` helper로 분리하면 context menu에서는 command 완료를 기다릴 수 있다.
- body 선택 범위는 `applyParaFormatRange`, 표 셀 텍스트 caret은 `applyParaFormatInTableCell`로 분기해야 한다.
- 기존 paragraph format command를 재사용하면 Flutter-native editor 기능을 늘리면서도 Rust/FRB command surface를 불필요하게 늘리지 않을 수 있다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu decreases paragraph indent"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu increases table text paragraph indent"`
- `flutter test test/rhwp_widget_test.dart`
