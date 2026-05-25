# Web Release Build Verification

## 작업한 내용

- `example` 앱의 Web release build를 현재 main 기준으로 다시 실행했다.
- Web editor default mode, Web sample autoload, export artifact API 변경 이후에도
  `flutter build web`가 완료되는지 확인했다.
- Flutter Web의 Wasm dry run warning이 dependency lint warning 수준으로 표시되고,
  실제 JS Web build 산출물은 생성되는 것을 확인했다.

## 이 작업을 진행한 이유

사용자가 `flutter run -d chrome`에서 `WebAssembly.instantiate()` 관련 오류와
`ScaffoldMessenger` 오류를 보고했다. 이후 example 앱은 Web에서 upstream Web editor
mode를 기본값으로 사용하도록 바뀌었고, startup 시 FRB WASM 초기화를 피하도록
정리했다.

이 변경이 최소한 release Web build를 깨뜨리지 않는지 확인해야 했다. build 검증은
runtime 검증보다 좁은 범위지만, Web 배포 산출물을 만들 수 있는지 확인하는 기본
gate다.

## 이 작업을 통해 배울점

- Flutter Web build의 Wasm dry run warning은 JS Web build 실패와 동일하지 않다.
  이번 실행에서는 `flutter_rust_bridge` dependency 내부 lint warning이 출력됐지만
  build는 완료됐다.
- `flutter build web` 통과는 정적 컴파일과 asset bundling을 검증한다. 브라우저에서
  실제 editor module 로딩, COOP/COEP, WASM 초기화까지 완전히 검증하려면 별도의
  runtime browser test가 필요하다.
- 현재 환경에서는 로컬 browser 접근이 보안 정책으로 차단되어 runtime browser
  검증은 진행하지 못했다. 이 한계는 build 검증 결과와 분리해서 기록해야 한다.

## 검증

- `(cd example && flutter build web)`
- 결과: `Built build/web`
- 제한: 로컬 URL browser runtime 검증은 현재 환경의 browser 보안 정책 때문에
  수행하지 않았다.
