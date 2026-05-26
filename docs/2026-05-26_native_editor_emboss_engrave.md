# 2026-05-26 Native Editor Emboss Engrave

## 작업한 내용

- Flutter 공개 명령 API에 `emboss`, `engrave` 글자 속성을 추가했다.
- 네이티브 에디터 서식 리본에 Emboss/Engrave 버튼을 추가했다.
- collapsed selection 상태에서 설정한 Emboss/Engrave가 다음 본문 입력과 표 셀 입력에 적용되도록 pending character format에 연결했다.
- 글자 모양 다이얼로그에 Emboss/Engrave 선택지를 추가했다.
- Dart 직렬화 테스트와 Rust facade 명령 테스트에 Emboss/Engrave 속성을 추가했다.

## 이 작업을 진행한 이유

rhwp core는 이미 HWP 글자 모양의 양각/음각 속성을 파싱하고 명령으로 적용할 수 있다. Flutter-native 에디터가 실제 rhwp 에디터에 가까워지려면 core에 있는 글자 모양 속성을 UI와 공개 API에서 직접 다룰 수 있어야 한다.

## 이 작업을 통해 배울점

- core가 이미 지원하는 속성이라도 Flutter 플러그인에서는 공개 command, document helper, toolbar, pending input, dialog, 테스트까지 한 번에 연결해야 사용자가 체감하는 기능이 된다.
- 서로 배타적인 글자 속성은 UI 토글과 pending 상태 모두에서 한쪽을 켜면 반대쪽을 끄는 규칙을 유지해야 한다.
- 네이티브 에디터는 “선택 영역에 즉시 적용”과 “다음 입력에 적용” 경로가 분리되어 있어 두 경로를 모두 테스트해야 한다.

## 검증

- `dart format`
- `cargo fmt`
- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml applies_commands_exports_and_reopens`

Flutter widget test 실행은 sandbox에서 localhost test server socket 생성이 막혀 실패할 수 있다.
