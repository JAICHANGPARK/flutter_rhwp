# Native Editor Table Properties

## 작업한 내용

- `RhwpTableProperties` 모델과 `RhwpDocument.tableProperties()` / `setTableProperties()` API를 추가했다.
- Rust command facade에서 `getTableProperties`, `setTableProperties` JSON command를 rhwp core의 표 속성 조회/수정 API로 연결했다.
- Flutter-native editor 표 리본과 표 선택 컨텍스트 메뉴에 `Table properties` 진입점을 추가했다.
- `표 속성` 다이얼로그에서 셀 간격, 셀 안 여백, 쪽 나눔 방식, 제목 줄 반복 여부를 수정할 수 있도록 했다.
- Dart command serialization, document wrapper, Flutter widget flow, Rust facade 테스트를 추가했다.

## 이 작업을 진행한 이유

upstream rhwp core는 표 속성 API를 이미 제공하지만 Flutter-native editor에서는 표 구조 편집과 셀 서식 중심으로만 노출되어 있었다. WebView 없이 실제 HWP 에디터에 가까워지려면 표 자체의 배치/반복/여백 속성을 Flutter 위젯에서 직접 수정할 수 있어야 한다.

## 이 작업을 통해 배울점

- Web editor가 쓰는 core 기능은 Dart command surface와 Flutter dialog를 추가해 native editor에 단계적으로 이식할 수 있다.
- 표 편집은 셀 단위 명령뿐 아니라 표 컨트롤 단위 속성 편집도 필요하므로, 선택된 표 위치 정보를 재사용하는 공통 흐름이 중요하다.
- 속성 다이얼로그는 조회 command와 수정 command를 분리해서 테스트하면 UI 초기값과 저장 JSON을 명확히 검증할 수 있다.
