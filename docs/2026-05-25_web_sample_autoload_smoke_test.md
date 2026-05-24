# 2026-05-25 Web Sample Autoload Smoke Test

## 작업한 내용

- `RhwpExampleApp`에 `webEditorModuleUrl` 주입점을 추가했다.
- Web widget test에서 example app을 기본 자동 샘플 열기 상태로 실행하고, upstream Web editor mode에서 sample bytes가 열림 상태로 반영되는지 확인했다.
- 테스트에서는 `sampleBytesLoader`로 fixture bytes를 주입하고 `webEditorModuleUrl`을 빈 문자열로 넘겨 외부 ESM import 없이 Web editor shell과 sample bytes 전달 경로만 검증한다.
- `RhwpWebEditor`는 빈 `moduleUrl`을 받으면 bootstrap script를 주입하지 않고 host element에 안내 메시지만 렌더링하도록 했다.
- README의 CI 설명과 CHANGELOG에 Web sample autoload smoke test 범위를 반영했다.

## 이 작업을 진행한 이유

- Web example은 시작 시 FRB WASM bridge를 즉시 초기화하지 않고 upstream Web editor mode로 샘플을 열도록 바뀌었다.
- 기존 Chrome widget test는 `autoOpenSample: false`라서 Web에서 실제 샘플 자동 열기 경로가 회귀되어도 잡지 못했다.
- 사용자가 겪은 `WebAssembly.instantiate()` 계열 오류는 eager bridge 초기화와 연결될 수 있으므로, Web editor 기본 경로가 bridge 없이 준비되는지 별도 smoke test가 필요하다.

## 이 작업을 통해 배울점

- Web-only fallback 경로는 UI shell만 확인해서는 부족하고, asset load와 상태 전환까지 포함해야 한다.
- 외부 ESM module을 실제로 import하지 않아도, module URL을 주입 가능하게 만들면 브라우저 widget test에서 deterministic하게 Web editor host 경로를 검증할 수 있다.
- Flutter bridge 초기화 검증과 upstream Web editor fallback 검증은 실패 원인이 다르므로 테스트를 분리해야 한다.

## 검증

- `dart format example/lib/main.dart example/test/widget_test.dart`
- `cd example && flutter test --platform chrome test/widget_test.dart`
- `cd example && flutter test`
- `flutter analyze`
- `git diff --check`
