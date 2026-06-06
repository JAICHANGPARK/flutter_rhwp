# Native editor format copy

## 작업한 내용

- Flutter-native editor에 character/paragraph format snapshot 상태를 추가했다.
- Edit 리본의 clipboard group에 `Copy format`과 `Apply copied format` 버튼을 추가했다.
- `Copy format`은 현재 body cursor/selection 또는 table-cell editing 위치에서 character properties와 paragraph properties를 core API로 다시 읽어 저장한다.
- `Apply copied format`은 저장된 character shape와 paragraph shape를 기존 `applyCharFormat*`, `applyParaFormat*` command 경로로 현재 선택 영역에 적용한다.
- 복사 전에는 적용 버튼이 비활성화되고, 복사 후 활성화되는 상태와 command payload를 widget test로 검증했다.

## 이 작업을 진행한 이유

upstream Web editor의 Edit 메뉴에는 모양 복사가 있다. Flutter-native editor가 단순 텍스트 편집을 넘어 실제 문서 편집기 경험에 가까워지려면 글자 모양과 문단 모양을 한 번에 복사해 다른 위치에 적용할 수 있어야 한다.

이미 Flutter-native editor에는 char/para property 조회와 적용 API가 있으므로, Rust core를 새로 건드리지 않고도 사용자가 기대하는 편집 흐름을 추가할 수 있었다.

## 이 작업을 통해 배울점

- 모양 복사는 clipboard text가 아니라 editor 내부 format snapshot에 가깝다.
- character shape와 paragraph shape는 적용 대상이 다르므로 둘을 분리해 저장하되 하나의 사용자 동작으로 적용해야 한다.
- 기존 command 경로를 재사용하면 body selection과 table-cell selection parity를 동시에 확보하기 쉽다.
- toolbar 상태는 기능 구현의 일부다. 복사 전 적용 버튼 비활성화처럼 사용 가능 상태를 명확히 해야 한다.

## 남은 점

- object shape/property copy는 별도 기능으로 분리해야 한다.
- format copy를 keyboard shortcut과 context menu에도 노출할지 결정해야 한다.
- table-cell range에 대한 format copy round-trip은 실제 샘플 문서로 추가 검증이 필요하다.

## 검증

```sh
dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor copies and applies character paragraph format"
```
