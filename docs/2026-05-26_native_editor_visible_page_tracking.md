# 2026-05-26 native editor visible page tracking

## 작업한 내용

- `RhwpViewer`가 세로 스크롤 위치를 기준으로 현재 보이는 페이지를 `RhwpViewerController.currentPage`에 반영하도록 했다.
- Flutter-native editor 상태바에 현재 페이지와 전체 페이지 수를 표시했다.
- 사용자가 직접 스크롤했을 때 current page가 갱신되는 viewer 테스트와, native editor 상태바가 페이지 이동을 반영하는 테스트를 추가했다.
- README와 CHANGELOG에 scroll-tracked current page 동작을 반영했다.

## 이 작업을 진행한 이유

upstream web editor는 단일 페이지 중심으로 `page-info`를 갱신한다. Flutter-native editor는 여러 페이지를 스크롤하는 구조라서, 사용자가 직접 스크롤하면 controller의 current page가 이전 명령 이동 값에 머물 수 있었다.

현재 보이는 페이지와 editor 상태 표시가 어긋나면 다음/이전 페이지 이동, 검색 결과 이동, 상태바 정보가 실제 화면과 다르게 느껴진다. viewer가 visible page를 controller에 동기화하면 Flutter-native editor가 WebView fallback 없이도 더 문서 편집기다운 상태 모델을 갖게 된다.

## 이 작업을 통해 배울 점

- Flutter의 lazy `ListView`에서는 모든 페이지가 항상 mount되어 있지 않으므로, 현재 mount된 page key만 이용해서 visible page를 계산해야 한다.
- controller의 current page는 명령형 `goToPage`뿐 아니라 사용자의 직접 스크롤에서도 갱신되어야 한다.
- 상태바는 선택 위치뿐 아니라 문서 viewport 상태도 함께 보여줘야 에디터 UX가 안정된다.

## 검증

- `flutter analyze`
- `cargo test --manifest-path rust/Cargo.toml --quiet`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpViewer updates current page from visible scroll position"`은 sandbox의 `127.0.0.1:0` socket 생성 제한 때문에 실행 환경에서 막힌다.
- 같은 이유로 `RhwpNativeEditor status bar tracks current page` 위젯 테스트도 현재 sandbox에서는 load 단계 전 검증이 막힌다.
