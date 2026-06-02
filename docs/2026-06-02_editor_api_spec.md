# Editor API spec

## 작업한 내용

- `docs/API_SPEC.md`를 추가해 viewer, native editor, full editor, export API를 정리했다.
- `RhwpNativeEditor` host callback을 파일 수명주기, dirty guard, export, print, image picker 기준으로 정리했다.
- 커스텀 툴바에서 사용할 `RhwpDocument` 명령 API를 File, Text, Formatting, Table, Object, Page, Field, Navigation 영역으로 나눠 매핑했다.
- README 문서 링크에 API spec을 추가했다.
- `CHANGELOG.md`와 `docs/TODO.md`에 API 명세 작업을 반영했다.

## 이 작업을 진행한 이유

플러그인 사용자는 기본 예제 앱만 보지 않는다. 자체 앱에 툴바나 메뉴를 만들 때 “이 버튼은 어떤 함수를 호출해야 하는가”를 알아야 한다. 특히 `RhwpNativeEditor`는 내부 리본이 많은 기능을 처리하지만, 외부 앱 메뉴나 커스텀 툴바는 `RhwpDocument` 명령 API를 직접 호출해야 한다.

또 파일 열기, 저장, 프린트, 이미지 선택은 플랫폼별 UX라서 플러그인이 혼자 처리할 수 없다. 그래서 editor callback과 command API를 분리해서 명세로 남겼다.

## 이 작업을 통해 배울점

- 에디터 포팅 작업에서는 UI 구현만큼 public API 설명이 중요하다.
- toolbar 명세는 단순 기능 목록이 아니라, host app 책임과 plugin 책임을 나누는 계약이다.
- upstream full editor는 내부 UI 중심이고, Flutter-native editor는 callback과 command API 중심이므로 문서에서 두 모델을 구분해야 한다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart
flutter analyze
cd example && flutter test test/widget_test.dart
git diff --check
```
