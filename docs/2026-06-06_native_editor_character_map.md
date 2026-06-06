# Native editor character map

## 작업한 내용

- Flutter-native editor 입력 리본에 `Character map` 버튼을 추가했다.
- 문자표 dialog를 추가해 기호, 화살표, 단위, 번호, 수식 문자 그룹을 선택할 수 있게 했다.
- 선택한 문자는 기존 `_insertTextValue` 경로를 통해 삽입되도록 했다.
- 기존 `_insertText` 흐름을 재사용 가능한 `_insertTextValue`로 분리해 일반 텍스트 입력, selection replacement, overwrite mode, pending character format, table-cell 입력 정책을 문자표에서도 공유한다.
- 문자표에서 `※`를 선택하면 `insertText` command가 현재 cursor 위치에 호출되는 widget test를 추가했다.

## 이 작업을 진행한 이유

upstream Web editor의 Insert 메뉴에는 문자표가 있고, 공문서 편집에서는 특수 기호와 단위 문자를 자주 사용한다. Flutter-native editor가 WebView 없이 실사용 가능한 편집기로 가려면 이런 일반 입력 기능을 독립 Flutter UI로 제공해야 한다.

문자표는 Rust command를 새로 추가하지 않아도 기존 텍스트 삽입 명령으로 구현할 수 있다. 따라서 native editor parity를 올리기 좋은 작은 기능 단위다.

## 이 작업을 통해 배울점

- 입력 기능은 새 command를 만들기 전에 기존 text insertion path를 재사용할 수 있는지 먼저 확인하는 것이 좋다.
- 문자표 같은 UI도 selection replacement, overwrite mode, pending format과 같은 editor 입력 정책을 공유해야 한다.
- 작은 dialog 기능도 widget test로 command payload를 고정하면 추후 리본 개편 때 regression을 막을 수 있다.

## 남은 점

- 사용자 지정 문자 목록이나 최근 사용 문자 저장은 아직 없다.
- 한자/유니코드 검색형 문자표가 필요하면 dialog를 확장해야 한다.
- 하이퍼링크, 캡션, 주석 입력은 별도 command/API 확인 후 구현해야 한다.

## 검증

```sh
dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor inserts a character from character map"
```
