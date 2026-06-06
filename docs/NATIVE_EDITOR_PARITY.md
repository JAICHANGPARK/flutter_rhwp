# Flutter-native editor parity

## 기준

- 기준일: 2026-06-06
- 대상: `RhwpNativeEditor` / `RhwpCommandEditor`
- 목표: WebView 기반 `RhwpFullEditor`를 유지하면서, upstream Web editor 경험을 Flutter widget 기반 editor로 단계적으로 대체한다.
- upstream 확인:
  - https://github.com/edwardkim/rhwp/tree/main/web
  - https://edwardkim.github.io/rhwp/
  - https://raw.githubusercontent.com/edwardkim/rhwp/main/web/editor.js

## 상태 기준

| 상태 | 의미 |
| --- | --- |
| 완료 | Flutter-native 리본/API/widget test가 있고 일반 사용 흐름이 동작한다. |
| 부분 | 핵심 명령은 있으나 upstream 메뉴 전체, dialog 세부 옵션, platform 검증이 남았다. |
| 미구현 | Flutter-native surface에 아직 해당 메뉴/API가 없다. |
| 검증 필요 | 구현은 있으나 실제 샘플 문서 round-trip 또는 플랫폼 검증이 부족하다. |

## File

| Upstream 메뉴 | Flutter-native 상태 | 현재 연결 |
| --- | --- | --- |
| 새로 만들기 | 완료 | `onNewRequested`, Ctrl/Cmd+N |
| 열기 | 완료 | `onOpenRequested`, Ctrl/Cmd+O |
| 저장 | 완료 | `RhwpExportIntent.save`, Ctrl/Cmd+S |
| 다른 이름으로 저장 | 완료 | Save As HWP/HWPX, Ctrl/Cmd+Shift+S |
| 편집 용지 | 완료 | Page setup dialog, F7 |
| 인쇄 | 부분 | `onPrintRequested` PDF artifact |
| 제품 정보 | 부분 | Document info dialog |

## Edit

| Upstream 메뉴 | Flutter-native 상태 | 현재 연결 |
| --- | --- | --- |
| 되돌리기 / 다시 실행 | 완료 | snapshot 기반 undo/redo |
| 오려 두기 / 복사 / 붙이기 | 완료 | 본문, 표 셀, 개체 clipboard. Paste는 system text와 내부 rich/object clipboard 상태 기반 활성화 |
| 모양 복사 | 완료 | character/paragraph format snapshot copy and apply |
| 지우기 | 부분 | delete text/range/object/table row/column |
| 모두 선택 | 완료 | body/table-cell select all |
| 찾기 / 찾아 바꾸기 / 다시 찾기 | 완료 | search/replace, F3 navigation |
| 찾아가기 | 부분 | go to page, cursor fields. 위치 종류 확장 필요 |
| 문서 비교 | 부분 | compare dialog |
| 문서 이력 관리 | 미구현 | history manager UI/API 필요 |

## View

| Upstream 메뉴 | Flutter-native 상태 | 현재 연결 |
| --- | --- | --- |
| 확대 / 축소 / 배율 | 완료 | toolbar/status zoom controls |
| 쪽 맞춤 / 폭 맞춤 | 완료 | fit page / fit width |
| 조판 부호 | 부분 | paragraph marks 중심. 전체 control marks 확장 필요 |
| 문단 부호 | 완료 | paragraph mark overlay |
| 투명 선 | 완료 | transparent table border overlay |
| 잘림 보기 | 미구현 | clipped object/page overflow 표시 정책 필요 |
| 격자 보기 / 격자 설정 | 미구현 | grid overlay/snap 설정 필요 |
| 도구 상자 | 부분 | Flutter ribbon tab surface |

## Insert

| Upstream 메뉴 | Flutter-native 상태 | 현재 연결 |
| --- | --- | --- |
| 표 | 완료 | insert table, row/column operations |
| 도형 | 부분 | rectangle/ellipse/line/textbox presets |
| 그림 | 완료 | `onImageRequested`, insert picture |
| 글상자 | 부분 | shape preset as textbox |
| 수식 | 완료 | equation insert dialog |
| 필드 입력 | 부분 | fields list/value/click-here properties 중심 |
| 캡션 넣기 | 부분 | 표 캡션과 그림 캡션 생성/설정/삭제 지원. shape/textbox 등 비그림 개체 캡션 검증 필요 |
| 문단 띠 | 미구현 | paragraph band command/UI 필요 |
| 주석 | 부분 | 숨은 주석 삽입/편집/삭제 dialog/API. 활성 표 셀 텍스트 caret 내부 삽입/조회/편집/삭제 지원. 일반 주석 변형, 저장 round-trip 검증 필요 |
| 각주 | 완료 | insert/read/edit/delete footnote text |
| 미주 / 각주·미주 모양 | 미구현 | endnote APIs/UI 필요 |
| 문자표 | 완료 | common symbol character map dialog |
| 하이퍼링크 | 부분 | 하이퍼링크 삽입/편집 dialog/API와 field marker 삭제. 활성 표 셀 텍스트 caret 내부 삽입과 `fieldId` 기반 편집 지원. HWPX field serialization round-trip 검증 필요 |
| 책갈피 | 완료 | list/add/delete/rename/navigation |
| 회전/대칭 | 부분 | object properties dialog/API에서 shape/picture rotation/flip 지원. 전용 ribbon preset/shortcut 검증 필요 |
| 개체 속성 | 부분 | object size/offset dialog, rotation/flip, picture caption settings |
| 개체 지우기 | 완료 | selected object delete |

## Format

| Upstream 메뉴 | Flutter-native 상태 | 현재 연결 |
| --- | --- | --- |
| 진하게 / 기울임 / 밑줄 | 완료 | char format toggle, shortcuts |
| 취소선 / 위첨자 / 아래첨자 / 양각 / 음각 | 완료 | char effect commands |
| 글자 모양 | 완료 | character shape dialog, Alt+L |
| 문단 모양 | 완료 | paragraph shape dialog, Alt+T |
| 문단 번호 모양 | 부분 | new number insertion. numbering style UI 필요 |
| 글머리표 모양 | 미구현 | bullet style command/UI 필요 |
| 한 수준 증가 / 감소 | 완료 | paragraph indent controls/shortcuts |
| 글자 크기 크게 / 작게 | 완료 | font size step buttons/shortcuts |
| 왼쪽 / 가운데 / 오른쪽 / 양쪽 정렬 | 완료 | paragraph alignment commands |
| 배분 정렬 | 부분 | API option 문서화/shortcut 보강 필요 |
| 줄 간격 늘림 / 줄임 | 부분 | preset 적용 가능. increment/decrement shortcut parity 필요 |
| 스타일 | 완료 | style picker, F6 |
| 개체 속성 | 부분 | selected object dialog, rotation/flip, picture caption settings |

## Page

| Upstream 메뉴 | Flutter-native 상태 | 현재 연결 |
| --- | --- | --- |
| 편집 용지 | 완료 | page setup |
| 쪽 테두리/배경 | 부분 | `getPageBorderFill`/`setPageBorderFill`, 간격/동일 테두리/단색 배경 dialog. 개별 방향 UI, 이미지/그라데이션/무늬 상세 옵션 필요 |
| 머리말 / 꼬리말 | 부분 | create/list/edit/clear text. preset templates 필요 |
| 새 번호로 시작 | 완료 | insert new page number |
| 현재 쪽만 감추기 | 완료 | page hide dialog |
| 쪽 나누기 / 단 나누기 | 완료 | page/column break commands |
| 단 / 다단 설정 | 부분 | `getColumnDef`/`setColumnDef`, 1/2/3단 quick preset, 단 수/종류/동일 너비/간격 dialog. 개별 너비/구분선 필요 |
| 구역 설정 | 부분 | `getSectionDef`/`setSectionDef`, 시작 번호/탭 간격/감춤 flags dialog. 전체 section 상세 옵션 필요 |

## Table

| Upstream 메뉴 | Flutter-native 상태 | 현재 연결 |
| --- | --- | --- |
| 표 만들기 | 완료 | insert table |
| 표/셀 속성 | 완료 | table/cell properties dialogs, 표 캡션 생성/설정/삭제 |
| 셀 테두리/배경 | 부분 | fill/border quick controls. full border matrix 필요 |
| 위/아래 줄 추가, 왼쪽/오른쪽 칸 추가 | 완료 | row/column insertion |
| 줄/칸 지우기 | 완료 | row/column deletion |
| 셀 나누기 / 셀 합치기 | 완료 | split/merge commands |
| 셀 높이를 같게 / 셀 너비를 같게 | 완료 | selected cell max width/height 기준 `resizeTableCells` |
| 블록 계산식 / 합계 / 평균 / 곱 | 완료 | formula field, SUM/AVG/PRODUCT selected-cell presets |
| 1,000 단위 구분 / 자릿점 넣기/빼기 | 완료 | 선택된 순수 숫자 셀 문단의 1,000 구분 토글, 소수 자릿수 증가/감소 |

## Tools

| Upstream 메뉴 | Flutter-native 상태 | 현재 연결 |
| --- | --- | --- |
| 환경 설정 | 미구현 | editor settings dialog 필요 |
| 찾기 도구 | 완료 | find/replace group |
| 문서 비교 | 부분 | compare dialog |
| 문서 이력 관리 | 미구현 | document history manager 필요 |

## 다음 구현 우선순위

1. 하이퍼링크/필드 round-trip 검증, 비그림 개체 캡션처럼 일반 문서 작성에 자주 쓰이는 Insert 메뉴를 보강한다.
2. 쪽 테두리/배경 상세 옵션, 다단 개별 너비/구분선, 구역 상세 옵션을 page backlog로 분리해 구현한다.
3. 문서 이력 관리는 upstream API 확인 후 별도 milestone으로 둔다.
