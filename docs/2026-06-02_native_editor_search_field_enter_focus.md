# 2026-06-02 native editor search field enter focus

## 작업한 내용

Flutter-native editor의 검색 입력창에서 live search와 Enter/Shift+Enter 결과 이동을 수행할 때
검색 입력창 focus가 유지되도록 변경했다.

기존에는 검색 결과를 선택하면서 editor focus를 항상 복원했기 때문에, 검색 입력창에서 Enter를 한
번 누른 뒤 다음 결과로 이동하려면 입력창을 다시 클릭해야 했다. 이제 검색 입력창이 focused인
상태에서 발생한 검색/이동은 검색창 focus를 유지하고, F3나 toolbar button처럼 editor surface에서
시작한 검색 이동은 기존처럼 editor focus를 유지한다.

## 이 작업을 진행한 이유

upstream web editor는 검색 입력에서 Enter를 누르면 다음/이전 결과로 이동하지만 입력창을 blur하지
않는다. Escape에서만 검색어를 지우고 입력창에서 빠져나온다.

Flutter-native editor도 WebView 없이 실제 에디터 UI가 되려면, 검색 field가 활성화된 동안에는
사용자가 계속 검색어를 수정하거나 Enter를 반복해서 결과를 순회할 수 있어야 한다. 반대로 Escape나
clear는 문서 편집면으로 돌아가는 동작이어야 하므로 두 focus 정책을 분리했다.

## 이 작업을 통해 배울점

문서 편집기의 focus 정책은 단일 규칙으로 처리하기 어렵다. 같은 검색 결과 선택이라도 진입점이
검색 field인지, editor shortcut인지, toolbar button인지에 따라 다음 입력 surface가 달라진다.

Flutter에서는 FocusNode 상태를 기준으로 진입점을 판별하고, selection/page 이동은 공통으로 쓰되
focus 복원만 다르게 적용하면 WebView 없이도 upstream editor의 입력 흐름에 더 가까워질 수 있다.

## 검증

검색 입력창에서 live search 후 focus가 유지되는지, Enter와 Shift+Enter를 반복해도 검색창을 다시
클릭할 필요가 없는지 widget test로 확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor debounces live search field input"
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor cycles search matches from search field keys"
```
