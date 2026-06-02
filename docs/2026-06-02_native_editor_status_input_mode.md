# 2026-06-02 native editor status input mode

## 작업한 내용

- Flutter-native editor 상태바의 `Insert`/`Overwrite` 표시를 클릭 가능한 입력 모드 토글로 만들었다.
- 텍스트 선택 중에는 상태바가 `Selection`을 표시하고 입력 모드 토글을 비활성화하도록 유지했다.
- 기존 Insert 키와 같은 `_toggleOverwriteMode` 경로를 재사용해 별도 문서 command 없이 Flutter editor 상태만 갱신한다.
- widget test로 Insert 키와 상태바 클릭이 같은 입력 모드 상태를 토글하는지 검증했다.

## 이 작업을 진행한 이유

WebView fallback 없이 Flutter 위젯 에디터를 실제 편집기로 키우려면 toolbar뿐 아니라 status bar도 편집 상태를 보여주는 데서 그치지 않고 조작 가능한 editor chrome이어야 한다. Insert/Overwrite는 HWP형 데스크톱 에디터에서 기본 입력 상태이므로, 키보드와 상태바 양쪽에서 같은 흐름으로 전환할 수 있게 했다.

## 이 작업을 통해 배울점

- status bar UI는 표시 전용 텍스트처럼 보여도 실제 편집 상태와 연결되면 사용성이 좋아진다.
- 입력 모드 전환은 문서 내용을 바꾸지 않으므로 Rust command, undo snapshot, dirty 상태와 분리해야 한다.
- selection 상태처럼 입력 모드와 다른 상태를 표시할 때는 같은 status bar 영역이라도 클릭 동작을 비활성화해야 상태 의미가 흐려지지 않는다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toggles overwrite mode with insert key and status bar"`
