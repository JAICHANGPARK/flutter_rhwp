# Native editor table caption

## 작업한 내용

- `RhwpTableProperties`가 `hasCaption`, `captionDirection`, `captionVertAlign`, `captionWidth`, `captionSpacing` 값을 파싱하도록 확장했다.
- `RhwpCommand.setTableProperties`와 `RhwpDocument.setTableProperties()`에 표 캡션 설정 파라미터를 추가했다.
- Flutter-native 표 속성 다이얼로그에 Caption 토글, 캡션 방향, 세로 정렬, 폭, 간격 입력을 추가했다.
- table properties widget test에서 표 캡션 생성 payload를 검증하도록 확장했다.
- API spec, parity matrix, TODO, CHANGELOG에 표 캡션 지원 범위와 남은 그림/개체 캡션 범위를 반영했다.

## 이 작업을 진행한 이유

upstream Web editor의 Insert 메뉴에는 캡션 넣기가 있다. Flutter-native editor에는 아직 별도 caption command가 없었지만, vendored rhwp core의 `setTableProperties`는 이미 표 캡션 생성과 속성 변경을 처리할 수 있었다.

따라서 새 core 구조를 만들기보다 이미 검증된 table properties 경로를 공개 Dart API와 Flutter-native dialog에 연결하는 것이 가장 작은 범위로 실제 editor parity를 높이는 방법이다.

## 이 작업을 통해 배울점

- 표 캡션은 table control 안의 `Caption` 모델이며, table properties command로 생성/수정할 수 있다.
- Flutter-native editor parity 작업은 core에 이미 있는 기능을 UI/API에서 빠뜨리지 않는 것만으로도 의미 있게 진전된다.
- “캡션 넣기” 전체를 완료 처리하려면 표뿐 아니라 그림, 도형, 글상자 같은 개체 캡션도 별도 command/UI로 다뤄야 한다.
- API 문서에서는 방향 enum 값을 숫자로만 두면 불명확하므로 `captionDirection`과 `captionVerticalAlign` 매핑을 명시해야 한다.

## 검증

```sh
flutter test test/flutter_rhwp_test.dart --plain-name "table row and column commands serialize to Rust envelopes"
flutter test test/flutter_rhwp_test.dart --plain-name "document convenience edit methods use command envelopes"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor edits table properties from table ribbon"
```
