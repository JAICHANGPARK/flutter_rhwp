# Native editor clipboard ribbon state

## 작업한 내용

- Flutter-native editor toolbar가 현재 body text selection을 받을 수 있게 했다.
- Cut/Copy 리본 버튼에 안정적인 widget key를 추가했다.
- Cut/Copy 버튼은 body text selection, table-cell selection, object selection 중 하나가 있을 때만 활성화되도록 했다.
- Paste 버튼은 기존처럼 busy 상태가 아니면 활성화해, 시스템 clipboard나 내부 rich/object clipboard paste 흐름을 실행할 수 있게 유지했다.
- 선택 전/후 Cut/Copy/Paste 버튼 활성 상태를 검증하는 widget test를 추가했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 에디터가 실제 문서 편집기처럼 보이려면 명령이 동작하는지뿐 아니라 현재 편집 context에 맞게 toolbar 상태가 바뀌어야 한다. 선택이 없는데 Cut/Copy가 활성화되어 있으면 사용자는 명령이 가능한지 판단하기 어렵고, host app이 custom toolbar를 만들 때 참고할 UI 계약도 흐려진다.

이번 작업은 WebView fallback과 별개로 Flutter-native editor의 리본 상태 관리를 한 단계 더 실제 에디터에 가깝게 맞춘 것이다.

## 이 작업을 통해 배울점

- command API가 있어도 toolbar state는 별도의 UX 계약이다.
- Flutter-native editor는 controller selection, table selection, object selection을 한 UI 상태로 합쳐야 한다.
- 안정적인 widget key를 붙이면 리본 상태 같은 상호작용 품질을 regression test로 유지할 수 있다.
- Paste는 clipboard 접근 제약이 플랫폼마다 다르므로, 실제 clipboard readable 상태와 버튼 활성화를 연결할지는 별도 설계가 필요하다.

## 남은 점

- Paste 활성 상태를 실제 system clipboard, 내부 rich text clipboard, object clipboard 상태와 연결할지 결정해야 한다.
- table-cell selection과 object selection의 Cut/Copy 리본 활성 상태도 별도 targeted test로 보강할 수 있다.

## 검증

```sh
dart format lib/src/rhwp_editor.dart test/rhwp_widget_test.dart
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor enables clipboard ribbon actions for selections"
```
