# Native editor line spacing presets

## 작업한 내용

- `RhwpNativeEditor` 서식 리본의 문단 모양 그룹에 줄 간격 프리셋 드롭다운을 추가했다.
- 프리셋은 upstream 웹 에디터 toolbar와 맞춰 100, 120, 130, 140, 150, 160, 180, 200, 250, 300%를 제공한다.
- 선택된 프리셋은 기존 `applyParaFormat` / `applyParaFormatRange` 경로를 사용해 `lineSpacing`과 `lineSpacingType: Percent`를 적용한다.
- 선택 영역에 프리셋을 적용하는 위젯 테스트를 추가했다.
- `CHANGELOG.md`와 `README.md`에 네이티브 서식 리본의 줄 간격 프리셋을 반영했다.

## 이 작업을 진행한 이유

upstream `web/editor.html` 에디터는 줄 간격 프리셋을 toolbar에서 직접 제공한다. Flutter-native 에디터도 문단 모양 다이얼로그만으로 줄 간격을 바꾸는 단계에서 벗어나, 반복 사용되는 문단 편집 기능을 리본에서 바로 실행할 수 있어야 한다.

## 이 작업을 통해 배울 점

- 큰 WYSIWYG 포팅은 문서 엔진보다 자주 쓰는 toolbar 조작을 하나씩 Flutter 위젯으로 옮기는 방식이 현실적이다.
- 이미 있는 Rust command를 재사용하면 UI parity 기능을 추가할 때 bridge 표면을 불필요하게 늘리지 않아도 된다.
- 프리셋 UI는 복잡한 dialog보다 빠른 편집 흐름에 맞고, 다이얼로그는 세부 설정용으로 남기는 구조가 낫다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies line spacing preset from ribbon"`는 현재 샌드박스가 Flutter test의 `127.0.0.1:0` 서버 소켓 생성을 막아 실행하지 못했다.
