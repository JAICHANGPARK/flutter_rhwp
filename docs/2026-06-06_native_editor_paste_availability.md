# Native editor paste availability

## 작업한 내용

- `RhwpNativeEditor` 리본의 Paste 버튼을 항상 활성화하지 않고, 실제로 붙여 넣을 데이터가 있을 때만 활성화하도록 바꿨다.
- 시스템 clipboard는 `Clipboard.hasStrings()`로 확인한다.
- 같은 editor session 안에서 만든 rich text HTML clipboard와 object clipboard는 내부 상태로 판단한다.
- 에디터 초기화 시점과 포커스 재진입 시점에 clipboard 상태를 다시 읽는다.
- 복사/오려 두기 후에는 시스템 clipboard 상태를 즉시 반영해서 Paste 버튼이 활성화된다.
- 위젯 테스트에서 빈 clipboard, 선택 상태, 복사 후 Paste 활성 상태 전환을 검증한다.

## 이 작업을 진행한 이유

기존에는 Paste 버튼이 `busy` 상태만 보고 활성화되어 있었다. 사용자는 버튼이 켜져 있으면 붙여 넣을 데이터가 있다고 기대하므로, toolbar 상태가 실제 clipboard 상태와 맞아야 한다.

또한 native editor parity 문서에서 Paste 활성 상태가 미완료로 남아 있었기 때문에, 본문/표/개체 clipboard 구현과 UI 상태를 같은 기준으로 정리할 필요가 있었다.

## 이 작업을 통해 배울점

- Flutter clipboard API는 동기적으로 읽을 수 없으므로, 버튼 상태는 비동기 조회 결과를 state로 캐시해야 한다.
- 시스템 clipboard와 editor 내부 rich/object clipboard는 성격이 다르다. 텍스트는 시스템 clipboard 기준으로 보고, HTML/object는 같은 editor session에서 만든 내부 상태를 함께 봐야 한다.
- toolbar 버튼의 활성 상태는 명령 실행 가능성의 일부다. 실제 붙여 넣기는 실행 시점에 다시 clipboard 내용을 읽어 방어적으로 처리해야 한다.

## 검증

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor updates clipboard ribbon actions for paste availability"
flutter analyze
```
