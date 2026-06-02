# 2026-06-02 native editor ruler drag

## 작업한 내용

- Flutter-native ruler의 왼쪽 여백, 첫 줄 들여쓰기, 오른쪽 여백 마커를 드래그할 수 있게 했다.
- 드래그 중에는 Flutter marker 위치를 preview하고, 드래그 종료 시 HWP 단위로 환산해 기존 문단 포맷 command path에 연결했다.
- body 문단 selection과 table-cell paragraph selection 모두 기존 `_applyParagraphFormat` 경로를 재사용한다.
- widget test로 각 ruler marker drag가 `applyParaFormatRange` 명령을 생성하는지 검증했다.

## 이 작업을 진행한 이유

WebView fallback을 유지하더라도 Flutter-native editor가 실제 편집 surface가 되려면 toolbar 버튼뿐 아니라 편집기 chrome 자체가 문서 상태를 조작할 수 있어야 한다. ruler drag는 upstream 웹 에디터의 문단 조작 UI를 Flutter 위젯으로 옮기는 데 필요한 기본 상호작용이다.

## 이 작업을 통해 배울점

- ruler UI는 표시와 편집이 모두 문단 속성 모델에 연결되어야 자연스럽다.
- Flutter gesture는 touch slop이 있으므로 test에서는 실제 pan delta가 command 값으로 어떻게 환산되는지 명확히 검증해야 한다.
- 기존 command path를 재사용하면 undo, refresh, table-cell paragraph formatting 동작을 새 UI에서도 일관되게 유지할 수 있다.

## 검증

- `flutter test test/rhwp_widget_test.dart --name "ruler"`
