# flutter_rhwp API spec

## 기준

- 기준일: 2026-06-02
- 패키지 버전: `2026.6.2`
- import: `package:flutter_rhwp/flutter_rhwp.dart`

이 문서는 앱 개발자가 `flutter_rhwp`를 붙일 때 어떤 기능에 어떤 API를 호출해야 하는지 정리한다. `RhwpNativeEditor` 안의 기본 리본은 대부분 내부에서 처리하지만, 파일 선택, 저장, 프린트, 이미지 선택처럼 플랫폼 UX가 필요한 기능은 host app 콜백으로 연결해야 한다. 앱이 자체 툴바를 만들 때는 아래 `RhwpDocument` 명령 API를 직접 호출한다.

## 에디터 종류

| Surface | 용도 | 핵심 API |
| --- | --- | --- |
| `RhwpViewer` | Flutter-native 읽기 전용 viewer | `Rhwp.open`, `RhwpViewer`, `RhwpViewerController` |
| `RhwpNativeEditor` | Flutter widget 기반 native editor | `RhwpNativeEditor`, `RhwpEditorController`, `RhwpDocument` command API |
| `RhwpFullEditor` | upstream `@rhwp/editor` 전체 UI host | `RhwpFullEditor`, `RhwpFullEditorController.export*` |
| `RhwpWebEditor` | Web 전용 upstream editor embed | `RhwpWebEditor`, `RhwpWebEditorController.export*` |

`RhwpFullEditor`와 `RhwpWebEditor`는 upstream editor UI가 내부 메뉴와 툴바를 처리한다. Flutter 앱에서 직접 연결하는 공개 API는 현재 export 계열이 중심이다. Flutter-native 커스텀 툴바나 앱 메뉴는 `RhwpNativeEditor`와 `RhwpDocument` command API를 기준으로 만든다.

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

앱 저장 UI에는 `RhwpExportedDocument`를 우선 사용한다. 이 객체에는 `bytes`, `fileName`, `mimeType`, `format`이 들어 있다.

```dart
final exported = await document.exportDocument(
  RhwpExportFormat.hwp,
  sourceFileName: currentFileName,
);
await saveBytes(exported.bytes, exported.fileName, exported.mimeType);
editorController.markClean();
```

Web/WASM에서 일부 export, 특히 PDF는 플랫폼 제약으로 `RhwpUnsupportedPlatformException`이 발생할 수 있다.

## Custom toolbar command map

커스텀 툴바를 만들 때는 현재 cursor/selection/table/object context를 앱이 알고 있어야 한다. `RhwpNativeEditor`의 기본 리본은 이 context를 내부에서 계산하지만, 앱 외부 툴바는 선택 위치를 직접 관리하거나 `RhwpEditorController` 상태를 읽어야 한다.

### File

| 툴바 기능 | 호출 API |
| --- | --- |
| New | `Rhwp.createEmpty(fileName: ...)` |
| Open | `Rhwp.open(bytes, fileName: ...)` |
| Save HWP | `document.exportDocument(RhwpExportFormat.hwp)` |
| Save HWPX | `document.exportDocument(RhwpExportFormat.hwpx)` |
| Export PDF/DOCX/Text/Markdown/SVG | `document.exportDocument(format, page: page)` |
| Rename | `document.setFileName(name)` |
| Document info | `document.metadata()` |
| Close | `document.close()` |

### Text and paragraphs

| 툴바 기능 | 호출 API |
| --- | --- |
| Insert text | `document.insertText(section, paragraph, offset, text)` |
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
| Cell fill/border/vertical align | `document.applyTableCellStyle(...)` |
| Formula | `document.evaluateTableFormula(...)` |
| Delete table object | `document.deleteTableControl(...)` |
| Move table object | `document.moveTableOffset(...)` |

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
| Insert picture | `document.insertPicture(...)` |
| Insert shape | `document.insertShape(...)` |
| Delete object | `document.deleteObjectControl(...)` |
| Copy/paste object | `document.copyObjectControl(...)`, `pasteObjectControl(...)` |
| Object clipboard check | `document.clipboardHasObjectControl()` |
| Object HTML export fallback | `document.exportControlHtml(...)` |
| Paste HTML | `document.pasteHtml(...)` |
| Z-order | `document.changeObjectZOrder(...)` |
| Read object properties | `document.objectProperties(...)` |
| Set object properties | `document.setObjectProperties(...)` |
| Move line endpoint | `document.moveLineEndpoint(...)` |

### Page, header, footer

| 툴바 기능 | 호출 API |
| --- | --- |
| Page break | `document.insertPageBreak(...)` |
| Column break | `document.insertColumnBreak(...)` |
| New page number | `document.insertNewNumber(...)` |
| Page setup read/write | `document.pageSetup(...)`, `setPageSetup(...)` |
| Page hide read/write | `document.pageHide(...)`, `setPageHide(...)` |
| Create header/footer | `document.createHeader(...)`, `createFooter(...)` |
| Header/footer info/list | `document.headerFooter(...)`, `headerFooterList(...)` |
| Delete header/footer | `document.deleteHeaderFooter(...)` |
| Header/footer text | `document.insertTextInHeaderFooter(...)`, `deleteTextInHeaderFooter(...)` |

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
);

final exported = await controller.exportDocument(
  RhwpExportFormat.hwp,
  sourceFileName: fileName,
);
await saveBytes(exported.bytes, exported.fileName, exported.mimeType);
```

## 구현 규칙

- 모든 편집 명령은 async이므로 반드시 `await`한다.
- 명령 성공 후 viewer/editor 표시가 필요하면 metadata와 페이지 렌더를 갱신한다.
- HWP/HWPX 저장이 성공했을 때만 `controller.markClean()`을 호출한다.
- PDF/DOCX/Text/Markdown/SVG export는 별도 산출물 생성이며, 앱 정책상 저장으로 볼지 결정해야 한다. 기본 example은 HWP/HWPX 저장만 clean 상태로 본다.
- platform file picker, save dialog, print, download는 앱에서 구현한다.
- Web/WASM과 desktop/native는 지원 형식과 저장 결과 의미가 다를 수 있으므로 `RhwpUnsupportedPlatformException`과 저장 취소를 구분한다.
