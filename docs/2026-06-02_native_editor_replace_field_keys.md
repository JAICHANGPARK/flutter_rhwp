# 2026-06-02 native editor replace field keys

## 작업한 내용

Flutter-native editor의 도구 리본에서 `Replace` 입력 필드에 키보드 이벤트 처리를 추가했다.
Replace 필드에 포커스가 있을 때 Enter를 누르면 현재 활성 검색 결과에 대해 replace 명령을
실행하고, Escape를 누르면 replace 입력값을 비우고 필드 포커스를 해제한다.

기존 버튼 기반 replace 흐름은 유지했다. TextInput action으로 제출하는 경로도 그대로 두고,
raw Enter/Escape 키 이벤트만 Flutter `Focus` 핸들러로 보강했다.

## 이 작업을 진행한 이유

upstream web editor는 검색/바꾸기 입력 필드를 단순 텍스트 입력이 아니라 편집 명령의 일부로
다룬다. Flutter-native editor도 WebView fallback 없이 실제 문서 편집 UI가 되려면, 리본 필드가
마우스 버튼 없이 키보드만으로 동작해야 한다.

검색 필드는 이미 Enter, Shift+Enter, Escape 처리가 있었지만 replace 필드는 Enter 제출만
부분적으로 연결되어 있었다. 이번 작업으로 search/replace 리본의 키보드 UX를 더 일관되게
맞췄다.

## 이 작업을 통해 배울점

Flutter의 `TextField.onSubmitted`는 IME action이나 제출 이벤트에는 유용하지만, 데스크톱 편집기
같은 raw keyboard UX를 모두 표현하기에는 부족하다. 리본 입력 필드를 명령 입력으로 쓰려면
`Focus.onKeyEvent`를 같이 사용해 Enter/Escape 같은 키를 명시적으로 처리하는 편이 안정적이다.

또한 Escape는 텍스트만 비우는 것이 아니라 포커스 상태도 정리해야 한다. 그래야 사용자가 도구
입력 모드에서 빠져나왔다는 상태가 명확해지고, 이후 편집기 본문 입력과 충돌하지 않는다.

## 검증

다음 widget test를 추가해 replace 필드의 Enter/Escape 동작을 확인했다.

```sh
flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor handles replace field enter and escape keys"
```
