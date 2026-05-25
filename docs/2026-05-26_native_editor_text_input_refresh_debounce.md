# 2026-05-26 native editor text input refresh debounce

## 작업한 내용

- `RhwpNativeEditor`의 일반 텍스트 입력, 탭 입력, 붙여넣기, 키보드 기반 텍스트 삭제가 문서 명령은 즉시 실행하되 페이지 SVG 재렌더는 짧게 지연하도록 바꿨다.
- 지연된 refresh는 마지막 입력 후 한 번만 실행되며, 그 시점에 `onChanged`도 함께 호출된다.
- 스페이스 입력 시 페이지 렌더와 `onChanged`가 즉시 발생하지 않고 debounce 후 한 번 실행되는 위젯 테스트를 추가했다.
- 이후 `editRefreshDelay` 옵션을 추가해 앱에서 이 debounce 시간을 조절할 수 있게 했다.

## 이 작업을 진행한 이유

기존 구조는 입력 한 글자마다 `insertText` 명령 후 `_renderRevision`을 즉시 증가시켜 `RhwpViewer`가 페이지 SVG를 다시 요청했다. 실제 앱에서는 스페이스나 문자 입력 때마다 페이지가 refresh 되는 것처럼 보여 편집 흐름이 끊겼다.

문서 데이터는 즉시 rhwp 코어에 반영하되 렌더 갱신만 debounce 하면, 빠른 연속 입력 중에는 화면을 유지하고 입력이 잠깐 멈춘 뒤 한 번만 렌더 결과를 동기화할 수 있다.

## 이 작업을 통해 배울 점

- 네이티브 문서 편집기에서는 문서 모델 갱신과 화면 렌더 갱신을 같은 주기로 묶으면 입력 UX가 나빠진다.
- FRB/Rust 명령은 데이터 정합성을 위해 즉시 실행하더라도, 비싼 페이지 렌더와 export 동기화는 사용자 입력 cadence에 맞춰 지연시키는 편이 낫다.
- debounce는 임시 workaround가 아니라 Flutter-native 편집기로 가는 동안 필요한 렌더 스케줄링 계층이다.

## 검증

- `RhwpNativeEditor debounces text input page refresh` 위젯 테스트를 추가했다.
- 이 테스트는 스페이스 입력 직후에는 `renderPageSvg`와 `onChanged`가 호출되지 않고, debounce 시간이 지난 뒤 한 번만 호출되는지 확인한다.
