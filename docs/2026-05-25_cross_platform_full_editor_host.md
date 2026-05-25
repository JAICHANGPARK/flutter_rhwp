# Cross Platform Full Editor Host

## 작업한 내용

- `RhwpFullEditor` native 구현을 `webview_flutter`가 아니라 `webview_all` 기반으로
  바꿨다.
- 지원 대상은 Web 직접 임베드와 Android/iOS/macOS/Windows/Linux platform WebView로
  정리했다. Fuchsia만 명시적으로 제외한다.
- example 앱의 기본 모드를 지원 플랫폼 전체에서 `Full editor`로 열리도록 바꿨고,
  `Commands` 모드는 FRB command overlay로 남겼다.
- Linux example runner를 `GtkOverlay` 구조로 바꿔 `webview_all_linux`가 WebKitGTK
  platform view를 붙일 수 있게 했다.
- README와 CHANGELOG에 Windows WebView2, Linux WebKitGTK 4.1 전제를 문서화했다.
- Linux CI dependency에 `libwebkit2gtk-4.1-dev`를 추가해 WebView host가 빌드될
  수 있게 했다.
- `webview_all` 요구사항에 맞춰 Flutter SDK lower bound를 3.35.0으로 올렸다.
- macOS sandbox에서 WKWebView가 remote editor module을 로드할 수 있도록 example
  entitlements에 outgoing network client 권한을 추가했다.
- WebView bootstrap이 실패했을 때 검은 빈 화면이 아니라 Flutter overlay로 로딩/오류
  메시지가 보이도록 했다.
- upstream `@rhwp/editor`의 실제 파일 로드 API가 `loadFile(data, fileName)`임을
  확인하고, full editor 초기 bytes 주입 경로를 그 API로 수정했다.
- full editor SVG export 후보에 upstream 문서화 API인 `getPageSvg()`를 추가했다.

## 이 작업을 진행한 이유

`webview_flutter`는 Android, iOS, macOS 중심이라 Windows/Linux에서 같은 full editor
경험을 제공하기 어렵다. 사용자가 원하는 것은 Web에서만 되는 fallback이 아니라 데스크톱
앱에서도 `edwardkim/rhwp`의 upstream editor처럼 메뉴와 툴바가 있는 편집 화면이다.

따라서 `RhwpFullEditor`는 플랫폼별 native WebView 위에 upstream `@rhwp/editor`를
올리는 구조로 잡았다. Flutter-native command editor는 유지하되, 완성형 WYSIWYG 편집은
upstream editor를 호스팅하는 쪽이 현실적이다.

## 이 작업을 통해 배울점

- Flutter에서 "전 플랫폼 WebView"는 단일 공식 패키지 하나로 끝나는 영역이 아니다.
  Windows는 WebView2, Linux는 WebKitGTK처럼 OS별 런타임 전제가 있다.
- 플랫폼 view를 쓰는 Linux 앱은 runner 구조도 기능의 일부다. Dart 코드만 바꿔서는
  WebView가 안정적으로 앱 안에 붙지 않는다.
- macOS sandbox 앱은 로컬 HTML 문자열을 띄우더라도 WKWebView가 remote module을
  import하려면 network client entitlement가 필요하다.
- 외부 npm wrapper를 감쌀 때는 추정한 메서드명보다 published `index.d.ts`를 기준으로
  bridge를 맞춰야 한다. 이번 경우 `loadFile()`을 빠뜨리면 UI는 뜨지만 문서는 로드되지
  않는다.
- 사용자-facing API는 `unsupported`로 빨리 빠지는 것보다, 필요한 플랫폼 adapter를
  선택하고 OS 전제를 문서화하는 쪽이 제품 요구사항에 맞다.

## 검증

- `dart format lib test example`
- `flutter analyze`
- `flutter test`
- `(cd example && flutter test)`
- `git diff --check`
