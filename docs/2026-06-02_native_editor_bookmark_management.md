# 2026-06-02 Native Editor Bookmark Management

## 작업한 내용

- Flutter-native 에디터의 책갈피 다이얼로그 라벨과 버튼을 한글 UI로 정리했다.
- 기존 책갈피를 선택하면 이름 입력 필드에 선택한 이름이 반영되는지 검증했다.
- 입력 리본의 책갈피 다이얼로그에서 기존 책갈피 이름 변경 command가 실행되는지 테스트했다.
- 같은 다이얼로그에서 기존 책갈피 삭제 command가 실행되는지 테스트했다.

## 이 작업을 진행한 이유

- WebView fallback 없이 Flutter-native editor를 실제 편집기로 쓰려면 책갈피 같은 문서 참조 기능도 Flutter UI 안에서 일관되게 관리되어야 한다.
- 기존 구현은 추가 경로만 위젯 테스트로 검증되어 있었고, 이름 변경/삭제는 command가 연결되어 있어도 회귀를 잡을 증거가 부족했다.
- 다이얼로그 제목은 한글인데 내부 라벨과 버튼이 영어라 HWP 스타일의 한글 편집 UI와 어긋났다.

## 이 작업을 통해 배울점

- 조회 command인 `getBookmarks`와 편집 command인 `renameBookmark`/`deleteBookmark`는 dialog 선택 상태와 `_runEdit` snapshot 경로를 함께 검증해야 한다.
- 기존 목록을 선택할 때 입력 필드 동기화까지 테스트하면 이름 변경 UI의 실제 사용 흐름을 더 직접적으로 검증할 수 있다.
- 작은 reference 관리 기능도 UI 문구, command payload, snapshot 저장, `onChanged` 호출을 함께 확인해야 native editor 표면이 안정적으로 자란다.

## 검증

- `flutter analyze`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor insert ribbon adds a bookmark"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor insert ribbon renames a bookmark"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor insert ribbon deletes a bookmark"`
- `flutter test test/rhwp_widget_test.dart --plain-name "RhwpNativeEditor context menu inserts references"`
- `flutter test test/rhwp_widget_test.dart`
