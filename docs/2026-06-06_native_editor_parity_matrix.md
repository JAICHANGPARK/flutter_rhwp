# Native editor parity matrix

## 작업한 내용

- upstream `rhwp/web` 및 공개 `rhwp-studio` 메뉴를 기준으로 Flutter-native editor parity 문서를 추가했다.
- 파일, 편집, 보기, 입력, 서식, 쪽, 표, 도구 메뉴별로 완료/부분/미구현/검증 필요 상태를 분류했다.
- `docs/TODO.md`의 native editor parity backlog에서 대조표 작성과 미구현 명령 분류를 완료 항목으로 옮겼다.
- `docs/API_SPEC.md`에서 parity 문서를 참조하도록 했다.

## 이 작업을 진행한 이유

Flutter 위젯 기반 에디터는 WebView UI를 단순히 감싸는 작업이 아니라, upstream Web editor의 메뉴와 입력 레이어를 Flutter로 다시 만드는 작업이다. 기능을 계속 추가하려면 “무엇이 남았는지”를 코드 파일이나 기억에 의존하지 않고 문서로 추적해야 한다.

이번 문서는 다음 구현 단위를 고르는 기준을 만든다. 특히 완료된 기능과 부분 구현된 기능을 분리해, 이미 있는 명령을 다시 만드는 대신 실제 parity gap을 줄이는 작업에 집중할 수 있게 한다.

## 이 작업을 통해 배울점

- upstream 메뉴 이름이 같아도 Flutter-native에서는 host callback, `RhwpDocument` command API, controller state가 함께 필요하다.
- Web editor parity는 UI 버튼 수가 아니라 selection, shortcut, dialog, 저장/dirty 상태까지 포함해야 한다.
- 문서화된 gap은 TODO보다 더 구체적인 구현 단위가 된다.
- WebView fallback은 유지하되, Flutter-native editor는 parity matrix를 따라 제품 기능 단위로 키우는 것이 맞다.

## 남은 점

- `NATIVE_EDITOR_PARITY.md`는 메뉴 기준 대조표다. 각 항목의 실제 샘플 문서 round-trip 검증은 별도 테스트로 추가해야 한다.
- upstream `rhwp-studio`가 바뀌면 대조표도 갱신해야 한다.

## 검증

```sh
flutter analyze
git diff --check
```
