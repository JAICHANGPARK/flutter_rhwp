# Native editor table object offset

## 작업한 내용

- `RhwpCommand.deleteTableControl`과 `RhwpCommand.moveTableOffset`을 추가했다.
- Dart `RhwpDocument` 공개 API에서 표 컨트롤 삭제와 표 오프셋 이동을 호출할 수 있게 했다.
- Rust `apply_command` 브리지에서 rhwp core의 `deleteTableControl`, `moveTableOffset`을 호출하도록 연결했다.
- `RhwpNativeEditor`에서 선택된 표 객체를 삭제할 때 일반 도형 삭제 대신 표 전용 삭제 명령을 사용하도록 바꿨다.
- 선택된 표 객체를 드래그하면 `setObjectProperties`가 아니라 표 전용 `moveTableOffset` 명령으로 위치를 이동하도록 했다.
- 표 객체는 셀 크기/표 속성으로 편집하는 대상이므로 일반 객체 리사이즈 핸들을 숨기고 이동만 허용했다.
- Dart command serialization, document convenience API, widget interaction, Rust command bridge 테스트를 추가했다.

## 이 작업을 진행한 이유

Flutter-native 에디터가 upstream web editor처럼 표를 셀 편집 모드와 표 객체 모드로 나누려면, 표 객체 선택 상태에서 이동과 삭제가 실제 HWP 문서 모델에 반영되어야 한다.

기존 일반 객체 경로는 도형/그림 중심의 `deleteObjectControl`, `setObjectProperties`를 사용한다. 표는 rhwp core에 별도 API가 이미 있으므로, 표 객체에는 표 전용 API를 연결하는 편이 문서 모델과 더 잘 맞는다.

## 이 작업을 통해 배울 점

- Flutter 위젯 에디터는 WebView UI를 그대로 감싸는 방식이 아니라, Flutter 입력/선택 상태를 rhwp core 명령으로 하나씩 매핑해야 한다.
- 표는 도형과 같은 화면 객체처럼 보이지만, 내부 모델은 셀/행/열/문단을 가진 별도 컨트롤이라 전용 명령을 쓰는 것이 안전하다.
- Flutter-native 포팅은 큰 단위 전환보다 `선택 상태 -> 명령 -> 리렌더` 흐름을 기능별로 완성하는 방식이 검증하기 좋다.
