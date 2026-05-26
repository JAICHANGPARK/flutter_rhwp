# 2026-05-26 native editor caret char properties

## 작업한 내용

- rhwp core의 native `get_char_properties_at_native`, `get_cell_char_properties_at_native` API를 Flutter command surface에 노출했다.
- Dart에 `RhwpCharProperties` 모델과 `charPropertiesAt`, `cellCharPropertiesAt` convenience API를 추가했다.
- `RhwpNativeEditor`가 커서 또는 활성 표 셀 위치의 글자 속성을 조회해 format ribbon의 bold, underline, font size, color 상태에 반영하도록 했다.
- 기존 pending character format은 유지하되, 버튼 toggle 판단은 현재 문서 서식을 fallback으로 삼도록 조정했다.
- Dart command serialization, document API, widget ribbon sync 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream web editor는 caret 위치의 `getCharPropertiesAt` 결과를 사용해 toolbar 상태를 갱신한다. Flutter-native editor도 WebView 없이 실제 편집기처럼 보이려면 사용자가 문서의 기존 굵게/밑줄/글자 크기 위치에 커서를 놓았을 때 리본이 그 상태를 읽어와야 한다.

## 이 작업을 통해 배울 점

- Flutter-native editor 포팅은 버튼 command 추가만으로 끝나지 않고, 문서 상태를 다시 UI로 읽어오는 query path가 필요하다.
- Pending format과 현재 caret format은 다른 개념이다. 사용자가 버튼을 누르기 전에는 현재 문서 서식을 표시하고, 누른 뒤에는 pending override를 표시해야 한다.
- 표 셀 내부 텍스트는 일반 문단과 command 대상이 다르므로 char property query도 별도 cell context를 유지해야 한다.

## 검증

- `flutter analyze`
- `flutter test test/flutter_rhwp_test.dart --plain-name "RhwpDocument applies command helpers"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor reflects caret character properties in ribbon"`
