# Full Editor Surface

## 작업한 내용

- upstream `@rhwp/editor` 기반 편집기를 `RhwpFullEditor` public API로 승격했다.
- `RhwpFullEditorController`를 추가해 full editor export/save 흐름을 명확한 이름으로
  사용할 수 있게 했다.
- 기존 Flutter-native `RhwpEditor`는 command overlay라는 역할을 문서화하고,
  명시적인 `RhwpCommandEditor` 이름을 추가했다.
- example 앱의 기본 편집 모드를 `Full editor`로 표시하고, Flutter bridge 쪽은
  `Commands` 모드로 표시하도록 바꿨다.
- Web은 DOM에 직접 upstream editor를 붙이고, Android/iOS/macOS/Windows/Linux는
  `webview_all` 기반 platform WebView에서 같은 editor를 호스팅하도록 연결했다.
- Linux example runner는 `webview_all` Linux 구현 요구사항에 맞춰 `GtkOverlay` 안에
  Flutter view를 올리도록 바꿨다.
- README와 CHANGELOG에 full editor와 command editor의 차이를 반영했다.

## 이 작업을 진행한 이유

사용자가 기대한 에디터는 문서 위에서 바로 클릭하고 입력하며, 메뉴/툴바/서식/표 편집을
제공하는 `edwardkim/rhwp`의 upstream Web editor에 가깝다. 기존 `RhwpEditor`는 이름과
달리 `section / paragraph / offset / text`를 직접 넣어 Rust command를 보내는 초기
command overlay였기 때문에, 실제 에디터처럼 수정되지 않는 것이 정상 동작이었다.

이 혼동을 줄이기 위해 full editor와 command editor를 API 이름에서 분리했다. Web에서는
upstream `@rhwp/editor`를 `RhwpFullEditor`로 직접 쓰고, native에서는 `webview_all`로
같은 editor를 앱 안에 호스팅한다. Flutter-native 경로는 아직 command surface라는 점을
명확히 했다.

## 이 작업을 통해 배울점

- 기능 이름은 실제 사용자 경험과 맞아야 한다. command API 검증용 UI를 `Editor`라고
  부르면 완성형 WYSIWYG 편집기로 오해하기 쉽다.
- 복잡한 문서 에디터는 렌더링뿐 아니라 selection, input method, layout hit-testing,
  toolbar state, table editing을 모두 포함한다.
- 이미 upstream에 full editor가 있다면, Flutter 플러그인은 우선 그 편집 surface를
  명확히 노출하고 Rust bridge는 cross-platform open/save/export API에 집중하는 편이
  현실적이다.
- 완성형 문서 에디터는 WebView가 들어가더라도 플랫폼별 전제가 남는다. Windows는
  WebView2, Linux는 WebKitGTK 4.1과 `GtkOverlay` runner 구성이 필요하다.

## 검증

- `dart format lib test example`
- `flutter analyze`
- `flutter test`
- `(cd example && flutter test)`
- `git diff --check`
