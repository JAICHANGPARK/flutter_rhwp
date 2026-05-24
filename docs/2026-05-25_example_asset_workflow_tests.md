# 2026-05-25 Example Asset Workflow Tests

## 작업한 내용

- `example/integration_test/asset_workflow_test.dart`를 추가해 예제 앱의 번들 HWP asset을 실제로 여는 흐름을 검증한다.
- 테스트에서 metadata 읽기, 첫 페이지 SVG 렌더링, text/Markdown 추출, HWP/HWPX/DOCX/TXT/MD/SVG export를 확인한다.
- PDF는 큰 예제 문서 전체 변환 비용이 크기 때문에 이 workflow test에서는 제외하고, Rust facade의 빠른 PDF 구조 테스트로 검증한다.
- GitHub Actions desktop job의 Linux matrix에서 `xvfb-run -a flutter test integration_test -d linux`, macOS matrix에서 `flutter test integration_test/asset_workflow_test.dart -d macos`를 실행해 실제 desktop plugin loading 경로를 검증한다.
- macOS/iOS podspec 경로는 Rust library가 static library로 링크되므로 `Rhwp.ensureInitialized()`가 FRB `ExternalLibrary.process()`를 기본 loader로 사용하도록 보정했다.
- SwiftPM manifest는 Rust archive가 앱에 링크되지 않아 제거했고, Apple은 CocoaPods/cargokit 경로를 사용하도록 정리했다.
- README와 CHANGELOG에 예제 workflow 테스트 추가 내용을 반영했다.

## 이 작업을 진행한 이유

- 초기 목표의 Integration 항목은 단순 빌드뿐 아니라 파일 open/render/export 시나리오를 CI에 넣는 것을 요구한다.
- 기존 예제 테스트와 integration test는 앱 shell 또는 빈 문서만 확인해서, 사용자가 요청한 샘플 파일 열기와 저장/변환 흐름을 직접 검증하지 못했다.
- 예제 앱의 asset과 공개 Dart API를 함께 테스트하면, 패키지 API와 실제 예제 배선이 동시에 깨지는 상황을 더 빨리 발견할 수 있다.

## 이 작업을 통해 배울점

- 예제 앱은 데모 역할뿐 아니라 플러그인의 실제 사용 시나리오를 검증하는 통합 테스트 지점으로 활용할 수 있다.
- `flutter test`의 headless runner는 FRB FFI dynamic library를 자동으로 로드하지 못할 수 있으므로, 실제 plugin loading까지 보려면 desktop device integration test가 필요하다.
- GitHub Actions Ubuntu runner는 화면 서버가 없으므로 Linux desktop integration test는 `xvfb-run`으로 감싸야 한다.
- Apple 플랫폼에서 cargokit/CocoaPods로 Rust static library를 링크하면 FRB 기본 dynamic loader가 framework를 찾지 못할 수 있다. 이 경우 process loader로 현재 프로세스의 symbols를 조회해야 한다.
- process loader는 이미 링크된 symbols를 찾는 방식이라, Rust archive가 앱에 들어오지 않는 SwiftPM manifest만으로는 충분하지 않다.
- 큰 변환 결과 전체를 비교하지 않아도 format signature, non-empty output, 렌더링 문자열 같은 최소 신호를 묶으면 안정적인 workflow smoke test가 된다.

## 검증

- `flutter analyze`
- `flutter test`
- `cd example && flutter test`
- `cd example && flutter test integration_test/asset_workflow_test.dart -d macos`
- CI command: `cd example && flutter test integration_test/asset_workflow_test.dart -d macos`
- `git diff --check`
