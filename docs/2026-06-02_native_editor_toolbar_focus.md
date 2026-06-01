# 2026-06-02 Native Editor Toolbar Focus

## 작업한 내용

- Flutter-native 에디터의 글자 서식 툴바 액션이 실행될 때 에디터 포커스를 다시 요청하도록 수정했다.
- Bold, Italic, Underline, Strike, 위첨자, 아래첨자, 양각, 음각, 글꼴, 글자 크기, 글자색, 음영색, 글자 모양 액션에 동일한 포커스 유지 경로를 적용했다.
- 툴바에서 서식을 한 번 적용한 뒤 `Ctrl+I`, `Ctrl+U` 같은 후속 단축키가 현재 selection에 계속 적용되는 기존 회귀 테스트를 통과시켰다.

## 이 작업을 진행한 이유

Flutter-native 에디터는 툴바와 문서 입력면이 모두 Flutter 위젯이다. 툴바 버튼을 누른 뒤 포커스가 버튼에 남으면 사용자가 바로 누르는 편집 단축키가 문서 selection으로 전달되지 않는다. upstream 웹 에디터처럼 툴바 조작 후에도 편집 흐름이 끊기지 않으려면 툴바 액션이 에디터 포커스를 유지해야 한다.

## 이 작업을 통해 배울점

- Flutter 위젯 기반 에디터에서는 문서 엔진 명령뿐 아니라 FocusNode 소유권도 편집 UX의 일부다.
- 툴바 버튼은 명령을 실행하는 순간에도 입력면의 keyboard shortcut 경로를 살려 두어야 한다.
- 기존 테스트가 실패하는 넓은 묶음이 있을 때는 실패 원인을 분리해서 이번 작업과 직접 연결된 회귀부터 좁게 고치는 것이 안전하다.

## 검증

- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor toggles active character formatting off"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu formats selected table cell text"`
- `flutter test test/rhwp_widget_test.dart --plain-name "table cell text"`
- `flutter analyze`
- `git diff --check`
