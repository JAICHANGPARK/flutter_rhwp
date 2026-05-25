# 2026-05-26 native editor edit refresh delay

## 작업한 내용

- `RhwpNativeEditor`, `RhwpEditor`, `RhwpCommandEditor`에 `editRefreshDelay` 옵션을 추가했다.
- 텍스트 입력, 탭, 붙여넣기, 키보드 삭제처럼 `deferRefresh`를 쓰는 편집은 이 값만큼 기다린 뒤 페이지 SVG를 다시 렌더링한다.
- 예제 앱은 `editRefreshDelay: 1200 ms`를 사용하도록 바꿨다.
- 사용자 지정 refresh delay가 실제로 적용되는 위젯 테스트를 추가했다.

## 이 작업을 진행한 이유

기존 debounce는 350 ms라서 사용자가 천천히 입력하거나 스페이스를 누를 때마다 입력 간격이 debounce 시간을 넘으면 페이지가 계속 refresh 되는 것처럼 보였다.

문서 명령은 즉시 적용하되 렌더 refresh만 더 늦추면, 입력 중에는 Flutter pending text overlay가 화면을 유지하고 사용자가 잠시 멈춘 뒤 한 번만 SVG 렌더 결과와 동기화된다.

## 이 작업을 통해 배울 점

- 편집 명령 적용 주기와 렌더 동기화 주기는 분리해야 한다.
- HWP 페이지 SVG 렌더는 입력 이벤트마다 실행하기보다 사용자의 입력 cadence에 맞춰 조절하는 편이 자연스럽다.
- 패키지 기본 동작을 유지하더라도 예제 앱은 실제 체감 UX에 맞는 값을 명시해 두는 것이 좋다.

## 검증

- `RhwpNativeEditor honors custom edit refresh delay` 위젯 테스트를 추가했다.
- 테스트는 지정한 delay 전에는 `renderPageSvg`와 `onChanged`가 호출되지 않고, delay 이후 한 번만 호출되는지 확인한다.
