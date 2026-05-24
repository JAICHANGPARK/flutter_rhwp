# 2026-05-24 Example File Workflows And Web Editor

## 작업한 내용

- 사용자가 첨부한 HWP 파일을 `example/assets/korea_ai_action_plan_2026_2028.hwp`로 추가하고 예제 앱 시작 시 자동으로 열도록 했다.
- 예제 앱에 번들 샘플 열기, file picker로 HWP/HWPX 열기, 새 문서 생성, 데모 텍스트 삽입, HWP/HWPX/PDF/DOCX/TXT/MD 저장 또는 다운로드 흐름을 넣었다.
- `RhwpWebEditor`를 추가해 Web에서 upstream `@rhwp/editor` iframe 기반 에디터를 임베드할 수 있게 했다.
- 예제 앱 Web 화면에 `Flutter` / `Web editor` 토글을 추가했다. 기본은 기존 Flutter/FRB 브리지 기반 뷰어·편집기이고, Web editor 모드는 upstream `@rhwp/editor`를 동적으로 로드한다.
- `example/web/coi-serviceworker.js`와 `index.html` bootstrap을 추가해 FRB atomics WASM이 요구하는 COOP/COEP isolation을 로컬 Web 실행에서 활성화할 수 있게 했다.
- 초기 자동 로딩 실패 시 `ScaffoldMessenger` ancestor가 없어서 발생하던 Web 런타임 오류를 `scaffoldMessengerKey`로 수정했다.

## 이 작업을 진행한 이유

- 사용자가 실제 HWP 문서를 열고, 수정하고, 저장하고, 변환하는 흐름을 예제에서 바로 확인할 수 있어야 한다.
- Flutter-native 편집기는 아직 command overlay 수준이므로, Web에서는 upstream에서 제공하는 완성형 `@rhwp/editor`를 토글로 붙이는 편이 실제 사용성에 더 가깝다.
- FRB Web 경로와 upstream Web editor 경로를 둘 다 제공하면, 같은 예제에서 "크로스플랫폼 Flutter API"와 "브라우저 전용 완성형 에디터"를 비교할 수 있다.
- npm 설치를 저장소에 강제하지 않고 ESM module URL을 받도록 해, 앱마다 CDN, self-hosted build, Vite dev server를 선택할 수 있게 했다.

## 이 작업을 통해 배울점

- Flutter Web에서 외부 DOM 기반 에디터를 붙일 때는 `HtmlElementView`와 `platformViewRegistry`를 사용해 Flutter 렌더 트리 밖의 DOM mount point를 만들어야 한다.
- Web editor를 패키지에 직접 묶지 않으면 배포 유연성은 높아지지만, module URL과 CORS/COEP 정책을 앱이 책임져야 한다.
- `@rhwp/editor`의 파일 로딩 API는 iframe wrapper 버전에 따라 달라질 수 있으므로, 현재 구현은 `openBytes`, `loadBytes`, `openHwp`, `loadHwp`, `importHwp` 후보를 순서대로 시도한다.
- 브라우저에서 SharedArrayBuffer 기반 WASM을 안정적으로 실행하려면 HTTPS 또는 localhost뿐 아니라 COOP/COEP 헤더까지 확인해야 한다.

## 검증

- `flutter analyze`
- `cd example && flutter test`
- `cd example && flutter build web`

## 실행 메모

기본 upstream editor URL:

```sh
flutter run -d chrome
```

self-hosted 또는 Vite 개발 서버의 `@rhwp/editor` ESM build를 사용할 때:

```sh
flutter run -d chrome \
  --dart-define=RHWP_EDITOR_MODULE_URL=http://localhost:7700/path/to/editor.js
```
