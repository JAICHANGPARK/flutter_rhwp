# Native editor column presets

## 작업한 내용

- Rust facade에 `getColumnDef`와 `setColumnDef` JSON command를 추가했다.
- Dart 공개 API에 `RhwpColumnDef`, `RhwpColumnType`, `document.columnDef(...)`, `document.setColumnDef(...)`를 추가했다.
- Flutter-native Page 리본에 1단, 2단, 3단 빠른 설정 버튼을 추가했다.
- 2단/3단은 rhwp core의 `ColumnType::Distribute`에 해당하는 값으로 설정하고, 1단은 `Normal`로 되돌린다.
- Rust command test와 Flutter widget test로 command payload와 core round-trip을 검증한다.

## 이 작업을 진행한 이유

upstream Web editor의 쪽 탭에는 다단 설정이 있고, native editor parity 문서에서는 이 항목이 미구현으로 남아 있었다. 전체 다단 상세 dialog를 한 번에 구현하기보다, rhwp core에 이미 있는 `setColumnDef`를 먼저 플러그인 API와 Flutter 리본에 연결해서 실제 문서 구조를 바꾸는 경로부터 열었다.

## 이 작업을 통해 배울점

- upstream WASM API에 있는 기능은 JS를 호출하지 않고 Rust facade command로 노출하는 편이 Flutter native editor 방향에 맞다.
- section-level 명령은 body cursor, table selection, object selection 중 현재 section을 안정적으로 해석해야 한다.
- full dialog가 없어도 command-backed quick preset을 먼저 제공하면 native editor parity를 실제 사용 가능한 단위로 확장할 수 있다.

## 검증

```sh
cargo test --manifest-path rust/Cargo.toml inserts_page_and_column_break_commands
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor applies section column presets"
flutter analyze
```
