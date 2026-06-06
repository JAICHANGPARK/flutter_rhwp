# flutter_rhwp API spec

## 기준

- 기준일: 2026-06-06
- 패키지 버전: `2026.6.6`
- import: `package:flutter_rhwp/flutter_rhwp.dart`

이 문서는 앱 개발자가 `flutter_rhwp`를 붙일 때 어떤 기능에 어떤 API를 호출해야 하는지 정리한다. `RhwpNativeEditor` 안의 기본 리본은 대부분 내부에서 처리하지만, 파일 선택, 저장, 프린트, 이미지 선택처럼 플랫폼 UX가 필요한 기능은 host app 콜백으로 연결해야 한다. 앱이 자체 툴바를 만들 때는 아래 `RhwpDocument` 명령 API를 직접 호출한다.

Upstream Web editor 메뉴 대비 Flutter-native 구현 상태는 `docs/NATIVE_EDITOR_PARITY.md`에서 별도로 추적한다.

## 에디터 종류

| Surface | 용도 | 핵심 API |
| --- | --- | --- |
| `RhwpViewer` | Flutter-native 읽기 전용 viewer | `Rhwp.open`, `RhwpViewer`, `RhwpViewerController` |
| `RhwpNativeEditor` | Flutter widget 기반 native editor | `RhwpNativeEditor`, `RhwpEditorController`, `RhwpDocument` command API |
| `RhwpFullEditor` | upstream `@rhwp/editor` 전체 UI host | `RhwpFullEditor`, `RhwpFullEditorController.export*` |
| `RhwpWebEditor` | Web 전용 upstream editor embed | `RhwpWebEditor`, `RhwpWebEditorController.export*` |

`RhwpFullEditor`와 `RhwpWebEditor`는 upstream editor UI가 내부 메뉴와 툴바를 처리한다. Flutter 앱에서 직접 연결하는 공개 API는 현재 export 계열과 dirty 상태 확인이 중심이다. Flutter-native 커스텀 툴바나 앱 메뉴는 `RhwpNativeEditor`와 `RhwpDocument` command API를 기준으로 만든다.

## 문서 수명주기

| 기능 | 호출 API | 앱에서 할 일 |
| --- | --- | --- |
| 초기화 | `Rhwp.ensureInitialized()` | 보통 `Rhwp.open`이 내부 호출하므로 명시 호출은 선택이다. |
| 버전 확인 | `Rhwp.version()` | rhwp core 버전 표시나 진단에 사용한다. |
| HWP/HWPX 열기 | `Rhwp.open(bytes, fileName: name)` | file picker, asset, network 등에서 `Uint8List`를 준비한다. |
| 빈 문서 생성 | `Rhwp.createEmpty(fileName: name)` | 새 문서 버튼에서 호출하고 editor의 `document`를 교체한다. |
| 문서 닫기 | `document.close()` | 화면에서 제거한 뒤 세션을 해제한다. |
| 파일명 갱신 | `document.setFileName(name)` | 저장/export 파일명과 metadata를 맞춘다. |
| metadata | `document.metadata()` | 페이지 수, 원본 포맷, 파일명 표시를 갱신한다. |

페이지 번호와 문서 위치 값은 Dart API에서 0-based 기준이다. 예를 들어 첫 페이지는 `page: 0`, 첫 문단은 `paragraph: 0`이다.

## Native editor host callbacks

`RhwpNativeEditor`를 앱에 붙일 때 파일/플랫폼 작업은 아래 콜백으로 연결한다.

```dart
RhwpNativeEditor(
  document: document,
  controller: editorController,
  onDirtyChanged: updateUnsavedIndicator,
  onUnsavedChanges: confirmSaveDiscardCancel,
  onNewRequested: createBlankDocument,
  onOpenRequested: pickAndOpenDocument,
  onCloseRequested: closeDocument,
  onImageRequested: pickImageForEditor,
  onExported: saveExportedDocument,
  onPrintRequested: printPdfDocument,
  onChanged: refreshMetadata,
)
```

| Native editor 기능 | 콜백/API | 앱 구현 |
| --- | --- | --- |
| File > New, Ctrl/Cmd+N | `onNewRequested` | `Rhwp.createEmpty` 후 현재 document 교체. |
| File > Open, Ctrl/Cmd+O | `onOpenRequested` | file picker로 bytes 선택 후 `Rhwp.open`. |
| File > Close, Ctrl/Cmd+W | `onCloseRequested` | 현재 document 제거 후 `close()`. |
| Dirty guard | `onUnsavedChanges(action)` | 저장/폐기/취소 dialog를 표시하고 진행 여부를 `bool`로 반환. |
| 수정 상태 표시 | `onDirtyChanged`, `controller.dirty` | 저장 안 된 변경사항 indicator를 표시한다. |
| 저장 완료/폐기 처리 | `controller.markClean()` | host app이 저장 또는 폐기를 완료한 뒤 호출한다. |
| Export/Save | `onExported(RhwpExportedDocument)` | `bytes`, `fileName`, `mimeType`로 파일 저장 또는 다운로드. |
| Print | `onPrintRequested(RhwpExportedDocument)` | PDF artifact를 프린트/미리보기 흐름에 전달. |
| Picture insert | `onImageRequested()` | 이미지 picker 후 `RhwpEditorImage` 반환. |
| 문서 변경 후 metadata | `onChanged(document)` | `document.metadata()`를 다시 읽어 UI를 갱신한다. |

`dirty`는 마지막으로 인정된 HWP/HWPX 저장 또는 명시적 폐기 이후 메모리 안의 문서가 바뀐 상태를 뜻한다.

## Viewer API

| 기능 | 호출 API |
| --- | --- |
| viewer 표시 | `RhwpViewer(document: document)` |
| zoom in/out/reset | `RhwpViewerController.zoomIn()`, `zoomOut()`, `resetZoom()` |
| fit width/page | `RhwpViewerController.fitWidth()`, `fitPage()` |
| 직접 zoom 지정 | `controller.zoom = 1.25` |
| 페이지 이동 | `controller.goToPage(page)`, `previousPage()`, `nextPage()` |
| 현재 페이지 확인 | `controller.currentPage` |
| page overlay | `RhwpViewer(pageOverlayBuilder: ...)` |
| SVG 커스텀 렌더 | `RhwpViewer(svgBuilder: ...)` |

## Export API

| 기능 | 호출 API |
| --- | --- |
| 저장 metadata 포함 export | `document.exportDocument(format, sourceFileName: name, page: page)` |
| HWP 저장 | `document.exportHwp()` 또는 `exportDocument(RhwpExportFormat.hwp)` |
| HWPX 저장 | `document.exportHwpx()` 또는 `exportDocument(RhwpExportFormat.hwpx)` |
| PDF export | `document.exportPdf()` 또는 `exportDocument(RhwpExportFormat.pdf)` |
| DOCX export | `document.exportDocx()` 또는 `exportDocument(RhwpExportFormat.docx)` |
| text export | `document.exportText(page: page)` |
| Markdown export | `document.exportMarkdown(page: page)` |
| 현재 페이지 SVG | `document.exportPageSvg(page: page)` |
| 텍스트 추출 | `document.extractText(page: page)` |
| Markdown 추출 | `document.extractMarkdown(page: page)` |

앱 저장 UI에는 `RhwpExportedDocument`를 우선 사용한다. 이 객체에는 `bytes`, `fileName`, `mimeType`, `format`, `intent`가 들어 있다.

```dart
final exported = await document.exportDocument(
  RhwpExportFormat.hwp,
  sourceFileName: currentFileName,
  intent: RhwpExportIntent.save,
);
await saveBytes(exported.bytes, exported.fileName, exported.mimeType);
editorController.markClean();
```

| Intent | 의미 | host app 처리 |
| --- | --- | --- |
| `RhwpExportIntent.save` | 현재 문서의 primary save | 기존 파일 경로가 있으면 그 경로에 저장하고, 없으면 저장 위치를 묻는다. |
| `RhwpExportIntent.saveAs` | primary document Save As | 항상 새 저장 위치/파일명을 묻는다. |
| `RhwpExportIntent.export` | PDF/DOCX/Text/Markdown/SVG 같은 보조 산출물 | 저장하더라도 기본적으로 editor dirty 상태를 clean으로 보지 않는다. |

Web/WASM에서 일부 export, 특히 PDF는 플랫폼 제약으로 `RhwpUnsupportedPlatformException`이 발생할 수 있다.

## Custom toolbar command map

커스텀 툴바를 만들 때는 현재 cursor/selection/table/object context를 앱이 알고 있어야 한다. `RhwpNativeEditor`의 기본 리본은 이 context를 내부에서 계산하지만, 앱 외부 툴바는 선택 위치를 직접 관리하거나 `RhwpEditorController` 상태를 읽어야 한다.

### File

| 툴바 기능 | 호출 API |
| --- | --- |
| New | `Rhwp.createEmpty(fileName: ...)` |
| Open | `Rhwp.open(bytes, fileName: ...)` |
| Save | `document.exportDocument(currentFormat, intent: RhwpExportIntent.save)` |
| Save As HWP | `document.exportDocument(RhwpExportFormat.hwp, intent: RhwpExportIntent.saveAs)` |
| Save As HWPX | `document.exportDocument(RhwpExportFormat.hwpx, intent: RhwpExportIntent.saveAs)` |
| Export PDF/DOCX/Text/Markdown/SVG | `document.exportDocument(format, page: page)` |
| Rename | `document.setFileName(name)` |
| Document info | `document.metadata()` |
| Close | `document.close()` |

### Text and paragraphs

| 툴바 기능 | 호출 API |
| --- | --- |
| Insert text | `document.insertText(section, paragraph, offset, text)` |
| Insert symbol from character map | `RhwpNativeEditor` 기본 리본의 `Character map`, 내부적으로 `document.insertText(...)` |
| Delete text | `document.deleteText(section, paragraph, offset, count)` |
| Delete range | `document.deleteRange(section, startParagraph, startOffset, endParagraph, endOffset)` |
| Insert paragraph | `document.insertParagraph(section, paragraph)` |
| Split paragraph | `document.splitParagraph(section, paragraph, offset)` |
| Merge paragraph | `document.mergeParagraph(section, paragraph)` |
| Delete paragraph | `document.deleteParagraph(section, paragraph)` |
| Paragraph count/length | `document.paragraphCount(...)`, `document.paragraphLength(...)` |
| Section count | `document.sectionCount()` |

### Character and paragraph formatting

| 툴바 기능 | 호출 API |
| --- | --- |
| Bold/Italic/Underline/Strike | `document.applyCharFormat(...)` 또는 `applyCharFormatRange(...)` |
| Superscript/Subscript/Emboss/Engrave | `document.applyCharFormat(...)` |
| Font family/size/color/shade | `document.applyCharFormat(...)` |
| Read character state | `document.charPropertiesAt(...)` |
| Paragraph alignment | `document.applyParaFormat(...)` 또는 `applyParaFormatRange(...)` |
| Line spacing/indent/margins | `document.applyParaFormat(...)` |
| Read paragraph state | `document.paraPropertiesAt(...)` |
| Style list | `document.styleList()` |
| Apply body style | `document.applyStyle(...)` |
| Apply table-cell style | `document.applyCellStyle(...)` |

### Table

| 툴바 기능 | 호출 API |
| --- | --- |
| Insert table | `document.insertTable(...)` 또는 `createTableEx(...)` |
| Insert/delete row | `document.insertTableRow(...)`, `deleteTableRow(...)` |
| Insert/delete column | `document.insertTableColumn(...)`, `deleteTableColumn(...)` |
| Merge cells | `document.mergeTableCells(...)` |
| Split cell | `document.splitTableCell(...)`, `splitTableCellInto(...)`, `splitTableCellsInRange(...)` |
| Table properties | `document.tableProperties(...)`, `setTableProperties(...)` |
| Cell properties | `document.cellProperties(...)`, `setCellProperties(...)` |
| Resize cells | `document.resizeTableCells(...)` |
| Equalize selected cell width/height | 선택 셀들의 `document.cellProperties(...)`를 읽고 최대 width/height 기준 delta를 `document.resizeTableCells(...)`에 전달 |
| Cell fill/border/vertical align | `document.applyTableCellStyle(...)` |
| Formula | `document.evaluateTableFormula(...)` |
| Formula presets | 선택 범위를 A1 표기법으로 변환해 `=SUM(range)`, `=AVG(range)`, `=PRODUCT(range)`를 `document.evaluateTableFormula(...)`에 전달 |
| Delete table object | `document.deleteTableControl(...)` |
| Move table object | `document.moveTableOffset(...)` |

`setTableProperties(...)`는 cell spacing, padding, page break, repeat header뿐 아니라 표 캡션도 다룬다. `captionDirection`은 `0=Left`, `1=Right`, `2=Top`, `3=Bottom`이고, `captionVerticalAlign`은 `0=Top`, `1=Center`, `2=Bottom`이다.

```dart
await document.setTableProperties(
  section: section,
  paragraph: paragraph,
  controlIndex: controlIndex,
  hasCaption: true,
  captionDirection: 3,
  captionVerticalAlign: 0,
  captionWidth: 8504,
  captionSpacing: 850,
);
```

### Table-cell text

| 툴바 기능 | 호출 API |
| --- | --- |
| Insert cell text | `document.insertTextInTableCell(...)` |
| Delete cell text | `document.deleteTextInTableCell(...)` |
| Delete cell text range | `document.deleteRangeInTableCell(...)` |
| Split/merge cell paragraph | `document.splitParagraphInTableCell(...)`, `mergeParagraphInTableCell(...)` |
| Cell paragraph count/length | `document.cellParagraphCount(...)`, `cellParagraphLength(...)` |
| Cell character format | `document.applyCharFormatInTableCell(...)` |
| Cell paragraph format | `document.applyParaFormatInTableCell(...)` |
| Read cell character/paragraph state | `document.cellCharPropertiesAt(...)`, `cellParaPropertiesAt(...)` |
| HTML paste in cell | `document.pasteHtmlInCell(...)` |
| Export cell selection HTML | `document.exportSelectionInCellHtml(...)` |

### Objects and clipboard

| 툴바 기능 | 호출 API |
| --- | --- |
| Cut selected text/cell/object | `RhwpNativeEditor` 기본 리본 또는 `document.delete*` + clipboard 저장 |
| Copy selected text/cell/object | `RhwpNativeEditor` 기본 리본 또는 `document.exportSelectionHtml(...)` / `exportControlHtml(...)` |
| Paste clipboard text/object | `RhwpNativeEditor` 기본 리본 또는 `document.insertText(...)`, `pasteHtml(...)`, `pasteObjectControl(...)` |
| Insert picture | `document.insertPicture(...)` |
| Insert shape | `document.insertShape(...)` |
| Copy/apply character and paragraph shape | `RhwpNativeEditor` 기본 리본의 `Copy format` / `Apply copied format` |
| Delete object | `document.deleteObjectControl(...)` |
| Copy/paste object | `document.copyObjectControl(...)`, `pasteObjectControl(...)` |
| Object clipboard check | `document.clipboardHasObjectControl()` |
| Object HTML export fallback | `document.exportControlHtml(...)` |
| Paste HTML | `document.pasteHtml(...)` |
| Z-order | `document.changeObjectZOrder(...)` |
| Read object properties | `document.objectProperties(...)` |
| Set object properties | `document.setObjectProperties(...)` |
| Move line endpoint | `document.moveLineEndpoint(...)` |

`RhwpNativeEditor` 기본 리본은 body selection, table-cell selection, object selection이 있을 때만 Cut/Copy를 활성화한다. Paste 버튼은 시스템 clipboard에 문자열이 있거나 같은 editor session에서 만든 내부 rich/object clipboard가 있을 때 활성화되며, 실행 시 `insertText(...)`, `pasteHtml(...)`, `pasteHtmlInCell(...)`, `pasteObjectControl(...)` 중 현재 selection에 맞는 경로를 사용한다.

`Copy format`은 현재 cursor 또는 table-cell editing 위치의 character/paragraph properties를 snapshot으로 저장한다. `Apply copied format`은 저장된 character shape와 paragraph shape를 현재 body selection 또는 table-cell selection에 적용한다.

### Page, header, footer

| 툴바 기능 | 호출 API |
| --- | --- |
| Page break | `document.insertPageBreak(...)` |
| Column break | `document.insertColumnBreak(...)` |
| Multi-column section presets/settings | `document.columnDef(...)`, `document.setColumnDef(...)` |
| New page number | `document.insertNewNumber(...)` |
| Section settings | `document.sectionDef(...)`, `document.setSectionDef(...)` |
| Page setup read/write | `document.pageSetup(...)`, `setPageSetup(...)` |
| Page border/background | `document.pageBorderFill(...)`, `setPageBorderFill(...)` |
| Page hide read/write | `document.pageHide(...)`, `setPageHide(...)` |
| Create header/footer | `document.createHeader(...)`, `createFooter(...)` |
| Header/footer info/list | `document.headerFooter(...)`, `headerFooterList(...)` |
| Delete header/footer | `document.deleteHeaderFooter(...)` |
| Header/footer text | `document.insertTextInHeaderFooter(...)`, `deleteTextInHeaderFooter(...)` |

```dart
final border = RhwpBorderLine(type: 1, width: 2, color: '#000000');
await document.setPageBorderFill(
  section: section,
  spacingLeft: 283,
  spacingRight: 283,
  spacingTop: 566,
  spacingBottom: 566,
  borderLeft: border,
  borderRight: border,
  borderTop: border,
  borderBottom: border,
  fillColor: '#fef08a',
);
```

### References, fields, bookmarks

| 툴바 기능 | 호출 API |
| --- | --- |
| Insert footnote | `document.insertFootnote(...)` |
| Find/read/delete footnote | `document.footnoteAtCursor(...)`, `footnoteInfo(...)`, `deleteFootnote(...)` |
| Footnote text | `document.insertTextInFootnote(...)`, `deleteTextInFootnote(...)` |
| Insert equation | `document.insertEquation(...)` |
| Bookmark list/add/delete/rename | `document.bookmarks()`, `addBookmark(...)`, `deleteBookmark(...)`, `renameBookmark(...)` |
| Field list | `document.fields()` |
| Get/set field value | `document.fieldValue(...)`, `setFieldValue(...)`, `fieldValueByName(...)`, `setFieldValueByName(...)` |
| Field at cursor | `document.fieldInfoAt(...)`, `fieldInfoAtInTableCell(...)` |
| Active field | `document.setActiveField(...)`, `setActiveFieldInTableCell(...)`, `clearActiveField()` |
| Remove field | `document.removeFieldAt(...)`, `removeFieldAtInTableCell(...)` |
| ClickHere properties | `document.clickHereProperties(...)`, `updateClickHereProperties(...)` |

### Navigation and rendering

| 기능 | 호출 API |
| --- | --- |
| Page count | `await document.pageCount` |
| Render SVG | `document.renderPageSvg(page)` |
| Raw layer tree | `document.pageLayerTree(page)` |
| Parsed layer tree | `document.pageLayerTreeModel(page)` |
| Position to page | `document.pageOfPosition(section, paragraph)` |
| Viewer page move | `RhwpViewerController.goToPage(page)` |

## Full editor export

`RhwpFullEditor`는 upstream editor UI를 그대로 host한다. Flutter 앱에서 파일 저장 버튼을 별도로 만들 경우 controller export API를 쓴다.

```dart
final controller = RhwpFullEditorController();

RhwpFullEditor(
  controller: controller,
  initialBytes: bytes,
  fileName: fileName,
  onDirtyChanged: updateUnsavedIndicator,
);

final exported = await controller.exportDocument(
  RhwpExportFormat.hwp,
  sourceFileName: fileName,
);
await saveBytes(exported.bytes, exported.fileName, exported.mimeType);
controller.markClean();
```

| Full/Web editor 기능 | 호출 API | 앱 구현 |
| --- | --- | --- |
| 수정 상태 표시 | `onDirtyChanged`, `controller.dirty` | upstream editor 내부 입력/클릭/붙여넣기/키 이벤트를 감지해 저장 안 된 변경사항 indicator를 표시한다. |
| 저장 완료/폐기 처리 | `controller.markClean()` | host app이 HWP/HWPX 저장 또는 변경 폐기를 완료한 뒤 호출한다. |
| 현재 문서 export | `controller.exportDocument(format, sourceFileName: name, intent: intent)` | full editor 내부 최신 상태를 bytes로 받아 저장하거나 mode switch에 사용한다. |

Full/Web editor dirty bridge는 upstream editor의 공식 edit 이벤트가 아니라 host가 삽입한 conservative 이벤트 감지다. 일반 입력, 붙여넣기, 삭제, Enter/Tab, toolbar-like 클릭은 dirty로 잡지만, upstream 내부에서 programmatic하게만 발생하는 일부 명령은 추가 검증이 필요하다.

## Mode switch handoff

앱이 `RhwpNativeEditor`와 `RhwpFullEditor`를 함께 제공한다면 editor mode switch는 저장이 아니라 in-memory handoff로 처리한다.

| 전환 | 권장 처리 |
| --- | --- |
| Native -> Full | `nativeDocument.exportHwp()`로 최신 bytes를 만들고 `RhwpFullEditor(initialBytes: bytes)`에 전달한다. 기존 dirty 상태는 유지한다. |
| Full -> Native | attached `RhwpFullEditorController.exportDocument(RhwpExportFormat.hwp)`를 호출한 뒤 그 bytes를 `Rhwp.open`으로 연다. full editor controller의 dirty 상태를 native editor controller로 넘긴다. |
| 전환 실패 | 기존 editor mode를 유지하고 사용자에게 실패 상태를 보여준다. |

## 구현 규칙

- 모든 편집 명령은 async이므로 반드시 `await`한다.
- 명령 성공 후 viewer/editor 표시가 필요하면 metadata와 페이지 렌더를 갱신한다.
- HWP/HWPX 저장이 성공했을 때만 `controller.markClean()`을 호출한다.
- PDF/DOCX/Text/Markdown/SVG export는 별도 산출물 생성이며, 앱 정책상 저장으로 볼지 결정해야 한다. 기본 example은 HWP/HWPX 저장만 clean 상태로 본다.
- platform file picker, save dialog, print, download는 앱에서 구현한다.
- Web/WASM과 desktop/native는 지원 형식과 저장 결과 의미가 다를 수 있으므로 `RhwpUnsupportedPlatformException`과 저장 취소를 구분한다.
