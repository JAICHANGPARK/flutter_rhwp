# flutter_rhwp TODO

## 진행률

- 전체 기준: rhwp Web editor 경험을 Flutter-native editor로 대체하고, 플러그인 API로 안정 제공하는 것.
- 현재 추정: 55~65%.
- 가장 큰 남은 비용: 기능 구현보다 실제 HWP 문서에서 편집 안정성, 저장 안정성, 플랫폼별 동작을 검증하는 부분.

## 이번 작업

- [x] 버전을 오늘 날짜 기준 `2026.6.2`로 올린다.
- [x] `CHANGELOG.md`를 날짜별 섹션 구조로 시작한다.
- [x] dirty 문서에서 New/Open/Close 전에 `onUnsavedChanges` guard를 호출한다.
- [x] example 앱에서 저장/폐기/취소 dialog를 통해 dirty 문서 파일 액션을 제어한다.
- [x] 데스크톱 저장 취소는 dirty 상태를 유지하고 파일 액션을 취소하도록 처리한다.
- [x] `RhwpNativeEditor` guard widget test를 추가한다.
- [x] 작업 문서 `docs/2026-06-02_native_editor_unsaved_changes_guard.md`를 추가한다.
- [x] 남은 작업을 `docs/ROADMAP.md`와 `docs/TODO.md`로 분리해서 관리한다.
- [x] 패키지 사용자용 editor/toolbar API 명세를 `docs/API_SPEC.md`로 추가한다.
- [x] native/full editor 전환 시 dirty 상태를 보존하고, full editor에서 native로 돌아갈 때 최신 HWP export bytes를 사용한다.
- [x] upstream full editor의 edit/dirty 이벤트를 Flutter controller로 브리지한다.
- [x] `flutter_rust_bridge`/codegen 2.12.0 갱신을 반영한다.
- [x] 버전을 오늘 날짜 기준 `2026.6.6`으로 올린다.
- [x] Save와 Save As intent를 `RhwpExportedDocument`에 분리하고 native editor 파일 리본에 반영한다.
- [x] example 앱에서 primary HWP/HWPX 저장 후 source bytes와 표시 파일명을 갱신한다.
- [x] CI의 `flutter_rust_bridge_codegen` 설치 버전을 `2.12.0`으로 맞춘다.
- [x] HWP/HWPX Save As 후 rhwp core 내부 file name metadata를 새 저장명으로 동기화한다.
- [x] Save/Save As 흐름에 대한 example widget test를 추가한다.
- [x] Flutter-native editor 클립보드 리본에서 선택 상태에 맞춰 Cut/Copy 활성 상태를 표시한다.
- [x] upstream Web editor 메뉴와 Flutter-native ribbon 항목을 1:1 대조표로 만든다.
- [x] 편집, 보기, 입력, 서식, 쪽, 표, 도구 탭별 미구현 명령을 분류한다.
- [x] 모양 복사 기능을 char/para format snapshot 기반으로 구현한다.
- [x] Flutter-native 입력 리본에 문자표 dialog를 추가한다.
- [x] Flutter-native 표 리본에 셀 높이/너비 같게 기능을 추가한다.
- [x] Flutter-native 표 리본에 SUM/AVG/PRODUCT 계산식 preset을 추가한다.
- [x] 클립보드 리본의 Paste 활성 상태를 실제 clipboard readable 여부와 내부 rich/object clipboard 상태에 연결한다.
- [x] Flutter-native Page 리본에 1/2/3단 다단 preset을 추가하고 `getColumnDef`/`setColumnDef` API를 연결한다.
- [x] Flutter-native Page 리본에 다단 상세 설정 dialog를 추가한다.
- [x] Flutter-native Page 리본에 구역 설정 dialog를 추가하고 `getSectionDef`/`setSectionDef` API를 연결한다.
- [x] 사용자 앱이 자체 툴바를 만들 때 필요한 `RhwpEditorController` context와 `RhwpDocument` command 연결 규칙을 `docs/API_SPEC.md`에 문서화한다.
- [x] Flutter-native 표 리본에 선택 숫자 셀 1,000 단위 구분과 소수 자릿수 증감 기능을 추가한다.
- [x] Flutter-native 개체 속성 dialog에 그림 캡션 생성/설정/삭제 기능을 추가한다.
- [x] Flutter-native 개체 속성 dialog에 선택 개체 회전/좌우 대칭/상하 대칭 기능을 추가한다.
- [x] Flutter-native 표 속성 dialog의 캡션 해제 동작을 rhwp core의 표 캡션 삭제로 연결한다.
- [x] Flutter-native 입력 리본에 하이퍼링크와 숨은 주석 삽입 기능을 추가한다.

## 다음 우선순위

- [ ] example 앱에 unsaved changes dialog widget test를 추가한다.
- [ ] upstream full editor dirty bridge를 실제 desktop WebView와 Web Chrome에서 수동 검증한다.
- [ ] upstream editor에서 공식 dirty/edit event를 제공하면 현재 conservative event bridge를 공식 event 기반으로 교체한다.
- [ ] 실제 첨부 샘플 문서로 open, edit, save, reopen, PDF export smoke test를 자동화한다.
- [ ] Save As metadata sync는 기본 로컬 파일 저장 경로에서는 저장 후 재-export로 파일 bytes까지 보정한다. Web 다운로드와 custom saver의 최종 파일명 변경은 플랫폼 API 한계 때문에 추가 설계가 필요하다.
- [ ] Web `WebAssembly.instantiate()`/cross-origin isolation 실행 조건을 README와 troubleshooting에 정리한다.
- [ ] Desktop full editor host의 black screen 원인을 플랫폼별로 분리해서 문서화하고 fallback 상태를 표시한다.
- [ ] `docs/API_SPEC.md`에 upstream Web editor 메뉴 대비 미구현 API를 계속 표시한다.

## Native editor parity backlog

- [ ] `docs/NATIVE_EDITOR_PARITY.md`의 부분/미구현 항목을 기능 단위 issue로 쪼갠다.
- [x] 하이퍼링크와 숨은 주석 입력 기능을 구현한다.
- [ ] 하이퍼링크/주석 편집, 삭제, 표 셀 내부 삽입, HWPX field serialization round-trip을 검증한다.
- [ ] Shape/textbox 등 비그림 개체 캡션 지원 가능 범위를 검증한다.
- [ ] 표 편집의 row/column sizing, border/fill, merge/split edge case를 실제 문서로 검증한다.
- [x] 표 숫자 서식 기능을 구현한다.
- [ ] 쪽 테두리/배경 상세 옵션, 다단 개별 너비/구분선, 구역 상세 옵션을 구현한다.
- [ ] 개체 편집의 image/shape/textbox/line 선택, 이동, 크기 변경, 회전/대칭, z-order edge case를 보강한다.
- [ ] 필드/누름틀, bookmark, footnote, header/footer의 문서 round-trip을 검증한다.
- [ ] IME composing, Space 입력, 빠른 입력, focus churn을 macOS/Windows/Linux에서 수동 검증한다.
- [ ] keyboard shortcut 목록을 문서화하고 누락된 shortcut을 채운다.

## Export and fidelity backlog

- [ ] PDF export snapshot 비교 기준을 정한다.
- [ ] DOCX export는 텍스트, 표, 이미지 구조 보존 기준으로 검증한다.
- [ ] HWP/HWPX round-trip 샘플을 늘린다.
- [ ] CJK font fallback과 text measurement 차이를 추적한다.
- [ ] renderPageSvg와 pageLayerTree가 같은 페이지 geometry를 공유하는지 regression test를 늘린다.

## Cross-platform backlog

- [ ] Android example open/edit/export smoke test.
- [ ] iOS simulator example open/edit/export smoke test.
- [ ] macOS example open/edit/export smoke test.
- [ ] Windows example open/edit/export smoke test.
- [ ] Linux example open/edit/export smoke test.
- [ ] Web WASM build와 Chrome 실행 smoke test.
- [ ] 플랫폼별 file picker/save dialog cancel 동작 검증.

## Release backlog

- [ ] `flutter analyze` 경고 없는 상태 유지.
- [ ] 주요 widget tests 통과.
- [ ] example widget tests 통과.
- [ ] `flutter pub publish --dry-run` 재검증.
- [ ] third-party notices와 vendored rhwp 정책 재확인.
- [ ] release tag와 GitHub release note 작성 기준 정리.
