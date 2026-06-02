# 2026-06-02 native editor replace field enter focus

## 작업한 내용

Flutter-native editor의 바꾸기 입력창에서 Enter로 active search match를 교체했을 때, 아직 다음
match가 남아 있으면 replace field focus를 유지하도록 변경했다.

기존에는 replace 실행 후 항상 editor focus로 돌아가서, 사용자가 다음 match를 다시 바꾸려면 replace
입력창을 다시 클릭해야 했다. 이제 replace field에서 시작한 Enter 동작은 다음 match가 남아 있을 때
replace field로 돌아가고, 마지막 match까지 처리한 뒤에는 기존처럼 editor surface로 돌아간다.

## 이 작업을 진행한 이유

Flutter-native editor를 WebView fallback 없이 실제 편집 UI로 키우려면, 검색/바꾸기 같은 보조 입력
surface도 연속 작업에 맞는 focus 정책이 필요하다. 검색 field의 반복 Enter 탐색과 마찬가지로,
replace field에서도 사용자가 같은 replacement를 여러 match에 빠르게 적용할 수 있어야 한다.

버튼으로 실행하는 replace와 입력창 Enter는 진입점이 다르다. toolbar button은 편집면으로 돌아가는
것이 자연스럽지만, replace field Enter는 다음 replace 입력을 받을 수 있도록 field focus를 유지하는
편이 더 일관적이다.

## 이 작업을 통해 배울점

문서 편집기에서 같은 command라도 호출한 UI surface에 따라 focus 결과가 달라져야 한다. Rust core
command는 동일하게 `deleteText`와 `insertText`를 실행하지만, Flutter 쪽 입력 레이어는 검색 field,
replace field, editor surface를 구분해 다음 키 입력의 목적지를 제어해야 한다.

또한 마지막 match를 처리한 뒤에는 더 이상 반복 replace 대상이 없으므로 editor surface로 돌아가게
두는 편이 검색/바꾸기 종료 흐름과 맞다.

## 검증

두 개의 search match가 있는 문서에서 replace field Enter를 두 번 연속 입력해도 첫 replace 뒤
field focus가 유지되고 두 번째 replace가 추가 클릭 없이 실행되는지 widget test로 확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles replace field enter and escape keys"
```
