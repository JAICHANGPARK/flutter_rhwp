# flutter_rhwp roadmap

## 현재 기준

- 기준일: 2026-06-06
- 패키지 버전: `2026.6.6`
- 전체 목표: `rhwp` 기반 HWP/HWPX 읽기, 보기, 편집, 저장, 내보내기를 Flutter 플러그인으로 제공한다.
- 전체 진행률 추정: 55~65%

이 진행률은 `edwardkim/rhwp`의 Web editor 경험을 Flutter-native editor로 대체하는 것을 100%로 본 기준이다. 단순 WebView 호스팅이나 SVG viewer만 기준으로 잡으면 더 높지만, 실제 한글 편집기처럼 파일 수명주기, 리본 UI, 표/개체/필드 편집, IME, 저장 안정성까지 포함하면 아직 남은 검증과 기능이 많다.

## 완료된 큰 영역

- `flutter_rust_bridge` 기반 Dart/Rust 브리지와 기본 HWP/HWPX 문서 세션.
- HWP/HWPX 열기, SVG 렌더링, 텍스트/Markdown 추출, HWP/HWPX/PDF/DOCX/SVG export API.
- example 앱의 bundled asset 열기, file picker 열기, export/save/download 흐름.
- `RhwpViewer`의 lazy page rendering, zoom, page overlay, page navigation.
- `RhwpNativeEditor`의 Flutter-native 리본, status bar, caret/selection overlay.
- 본문/표 셀 텍스트 입력, 삭제, 붙여넣기, 선택, undo/redo, 검색/바꾸기.
- 문자/문단/스타일/표/개체/필드/머리말/꼬리말 일부 편집 명령.
- 하이퍼링크와 숨은 주석 삽입을 위한 Flutter-native 리본/API/Rust command 경로.
- Web full editor fallback host와 Flutter-native editor toggle.
- dirty 상태, modified indicator, New/Open/Close unsaved changes guard.
- full editor/Web editor의 conservative dirty bridge와 mode switch dirty handoff.
- 주요 native editor widget test coverage.

## 남은 큰 영역

### 1. Native editor parity

목표는 Web editor에 기대하는 기본 문서 편집 경험을 Flutter widget만으로 제공하는 것이다.

- 리본 메뉴 항목과 단축키를 upstream Web editor 기준으로 대조한다.
- 본문/표/개체/필드/쪽/서식 메뉴의 미구현 항목을 채운다.
- dialog UI를 실제 HWP 편집기 작업 흐름에 맞게 다듬는다.
- 선택 상태, caret 상태, context menu 상태가 모든 편집 대상에서 일관되게 유지되는지 검증한다.

완료 기준:

- 일반 문서 작성/수정에 필요한 주요 메뉴가 Flutter-native surface에서 동작한다.
- Web full editor로만 가능한 핵심 편집 작업이 명확히 문서화되거나 Flutter-native로 구현되어 있다.

### 2. File lifecycle and save reliability

문서 열기, 새 문서, 닫기, 저장, 다른 이름 저장, export가 사용자의 편집 내용을 잃지 않도록 만든다.

- New/Open/Close guard를 example 외 앱에서도 쓰기 쉬운 API로 유지한다.
- 저장 취소, 저장 실패, export 실패, platform download 결과를 명확히 나눈다.
- HWP/HWPX 저장 후 dirty 상태와 원본 bytes/source metadata를 정확히 갱신한다.
- autosave/recovery가 필요한지 판단한다.

완료 기준:

- 사용자가 dirty 문서를 실수로 잃지 않는다.
- 모든 플랫폼에서 save/export 결과가 성공, 취소, 실패로 구분된다.

### 3. Rendering and document fidelity

실제 HWP 문서에서 페이지, 글꼴, 표, 이미지, 개체 배치가 안정적으로 보이도록 검증한다.

- 한국어 공공문서, 표 중심 문서, 이미지/도형 문서, 다단/쪽 설정 문서 샘플을 늘린다.
- SVG render와 PDF export snapshot을 비교한다.
- 폰트 fallback, CJK measurement, page pagination 차이를 추적한다.
- DOCX export는 픽셀 동일성이 아니라 문서 구조 보존 기준으로 검증한다.

완료 기준:

- 대표 샘플 문서에서 viewer/editor/export 결과가 실사용 가능한 수준으로 안정적이다.
- 알려진 fidelity 제한이 README와 docs에 정리되어 있다.

### 4. Cross-platform support

Android, iOS, macOS, Windows, Linux, Web에서 같은 API가 동작하도록 유지한다.

- FRB native build와 WASM build를 모두 검증한다.
- Web은 cross-origin isolation, WASM loader, download 동작을 문서화한다.
- Desktop full editor host는 `webview_all` 기반 지원 상태를 계속 확인한다.
- Linux/Windows/macOS에서 file picker와 save dialog 동작을 따로 검증한다.

완료 기준:

- example app이 주요 플랫폼에서 open, edit, save/export 기본 시나리오를 통과한다.
- unsupported가 필요한 경우는 API에서 명시적으로 드러난다.

### 5. Public API and package quality

패키지 사용자가 앱에 쉽게 붙일 수 있도록 API, 문서, 예제를 정리한다.

- README quick start, installation, usage, license를 짧고 최신 상태로 유지한다.
- Dart public API docs를 정리한다.
- example 앱을 실제 integration sample로 유지한다.
- `CHANGELOG.md`는 날짜별 섹션과 버전 섹션을 계속 유지한다.
- pub publish dry-run과 archive ignore 정책을 검증한다.

완료 기준:

- 새 사용자가 README만 보고 viewer/editor/export 기본 기능을 붙일 수 있다.
- 공개 API가 불필요하게 흔들리지 않는다.

## 작업 방식

- 기능 단위로 구현한다.
- 각 기능 단위마다 `docs/YYYY-MM-DD_workname.md`를 추가한다.
- `CHANGELOG.md`는 날짜별 섹션에 변경 사항을 추가한다.
- 가능하면 widget test 또는 integration test를 같이 추가한다.
- 검증 후 작업 단위로 commit/push한다.
