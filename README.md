# flutter_rhwp

Flutter plugin for reading, viewing, editing, saving, and exporting HWP/HWPX
documents.

- Repository: [JAICHANGPARK/flutter_rhwp](https://github.com/JAICHANGPARK/flutter_rhwp)
- Rust core: [edwardkim/rhwp](https://github.com/edwardkim/rhwp), vendored at
  `rust/vendor/rhwp`
- Bridge: `flutter_rust_bridge` v2
- Version: `2026.5.24`

## Features

- Open HWP/HWPX bytes.
- Render pages as SVG.
- Extract text and Markdown.
- Export HWP, HWPX, PDF, DOCX, text, Markdown, and page SVG.
- Use `RhwpViewer` for Flutter-native viewing.
- Use `RhwpFullEditor` for the upstream Web editor UI.
- Use `RhwpNativeEditor` for the Flutter widget editor track.
- Use `RhwpCommandEditor` for the earlier command-editor compatibility name.

## Installation

Until this package is published, add it from GitHub:

```yaml
dependencies:
  flutter_rhwp:
    git:
      url: https://github.com/JAICHANGPARK/flutter_rhwp.git
      ref: main
```

Then run:

```sh
flutter pub get
```

Requirements:

- Flutter `>=3.35.0`
- Windows full editor: Microsoft WebView2 runtime
- Linux full editor: WebKitGTK 4.1
- Sandboxed macOS full editor with remote `@rhwp/editor`: outgoing network
  client entitlement

## Quick Start

```dart
import 'dart:io';

import 'package:flutter_rhwp/flutter_rhwp.dart';

final bytes = await File('sample.hwp').readAsBytes();
final document = await Rhwp.open(bytes, fileName: 'sample.hwp');

final pageCount = await document.pageCount;
final firstPageSvg = await document.renderPageSvg(0);
final text = await document.extractText();
final exportedPdf = await document.exportDocument(RhwpExportFormat.pdf);

await document.close();
```

## Usage

Viewer:

```dart
RhwpViewer(document: document)
```

Full editor:

```dart
final controller = RhwpFullEditorController();

RhwpFullEditor(
  controller: controller,
  initialBytes: bytes,
  fileName: 'sample.hwp',
);

final editedHwp = await controller.exportHwp();
```

Flutter-native editor:

```dart
RhwpNativeEditor(
  document: document,
  editRefreshDelay: const Duration(milliseconds: 1200),
  onOpenRequested: pickAndOpenDocument,
  onImageRequested: pickImageForEditor,
  onExported: saveExportedDocument,
)
```

Edit with Rust bridge commands:

```dart
await document.insertText(
  section: 0,
  paragraph: 0,
  offset: 0,
  text: 'Hello',
);

await document.applyParaFormatRange(
  section: 0,
  startParagraph: 0,
  endParagraph: 2,
  alignment: 'center',
);

await document.insertTable(
  section: 0,
  paragraph: 0,
  offset: 0,
  rows: 2,
  columns: 3,
);

await document.insertTableRow(
  section: 0,
  paragraph: 0,
  controlIndex: 0,
  row: 0,
);

await document.insertPicture(
  section: 0,
  paragraph: 0,
  offset: 0,
  imageData: imageBytes,
  width: 15000,
  height: 10000,
  naturalWidthPx: 200,
  naturalHeightPx: 133,
  extension: 'png',
);

await document.insertShape(
  section: 0,
  paragraph: 0,
  offset: 0,
  shapeType: 'rectangle',
);

await document.createHeader(section: 0);
await document.createFooter(section: 0);

final snapshotId = await document.saveSnapshot();
await document.restoreSnapshot(snapshotId);

await document.mergeTableCells(
  section: 0,
  paragraph: 0,
  controlIndex: 0,
  startRow: 0,
  startColumn: 0,
  endRow: 1,
  endColumn: 1,
);
```

Export with save metadata:

```dart
final exported = await document.exportDocument(
  RhwpExportFormat.pdf,
  sourceFileName: 'sample.hwp',
);

// exported.bytes
// exported.fileName
// exported.mimeType
```

## Example

```sh
cd example
flutter run -d macos
```

The example can open the bundled HWP asset or a picked HWP/HWPX file, then
export HWP/HWPX/PDF/DOCX/TXT/MD/SVG.

## Notes

- `RhwpFullEditor` uses upstream `@rhwp/editor`.
- On Web it embeds the editor directly.
- On Android, iOS, macOS, Windows, and Linux it uses `webview_all`.
- Initial full-editor file loading uses `editor.loadFile(data, fileName)`.
- `RhwpNativeEditor` is the 100% Flutter widget editor path and currently
  includes an HWP-style Flutter ribbon toolbar, page viewport, page-layer caret
  hit testing, blinking caret/drag-selection overlay, keyboard caret movement
  including
  double-click word selection, triple-click paragraph selection, Shift+click
  selection extension, page-layer geometry based ArrowUp/ArrowDown,
  PageUp/PageDown, and Home/End,
  plus Ctrl/Cmd+Home/End, Ctrl/Option word navigation, and Ctrl/Option word
  delete, IME
  composing preview, context menus, HWP/HWPX/PDF export callbacks from the file
  ribbon, app-level file open callbacks and document information from the file
  ribbon, page navigation
  controls, transparent table border overlays, synchronized view/status zoom
  controls and Ctrl/Cmd zoom shortcuts, Ctrl/Cmd+mouse-wheel zoom, Escape state
  clearing, text commit, select-all,
  copy/cut/paste, Enter paragraph splitting, Shift+Enter soft line breaks,
  Tab text insertion, multiline clipboard paste as paragraph insertion,
  multi-paragraph selection
  replacement, multi-paragraph selected-text bold/italic/underline/strike
  formatting, inline font family, font size, text color, text background,
  superscript, subscript, emboss, and engrave controls, a character shape
  dialog with `Alt+L` shortcut support for font family, font size, text color,
  text background,
  superscript, subscript, emboss, and engrave, preloaded from the current
  caret character shape,
  collapsed-selection pending character
  formatting for the next inserted body text, caret character-shape sync for
  the format ribbon, caret paragraph alignment/line-spacing sync for the
  format ribbon, paragraph alignment commands and line-spacing presets,
  Ctrl/Cmd+L/E/R/J alignment shortcuts, a paragraph
  shape dialog that preloads the current caret paragraph's line spacing,
  indent, and paragraph margins, header/footer
  creation from the page ribbon,
  snapshot-backed undo/redo from the edit ribbon with continuous text-input
  undo batching, layer-tree text search with
  Ctrl/Cmd+F focus and search-text selection, F3/Shift+F3 and search-field
  Enter/Shift+Enter result navigation, debounced live search field input,
  search-field Escape clearing, result highlighting, active-match replace,
  replace-all, table-cell find/replace, and a tools-ribbon compare dialog
  backed by text extraction, and basic
  text/table/picture/shape
  insert/delete, with shape presets for rectangle, ellipse, line, and text box,
  page/column break insertion, plus table
  row/column and cell
  merge/split command flow with table-cell hit testing, selected-cell
  highlighting, object/control hit testing, highlighting, pointer drag move and
  resize handles for selected objects, Delete/Backspace object deletion, object
  size/position properties, and object z-order actions from the edit ribbon and
  context menu, scroll-preserving page refresh after edits, and drag range
  selection and Shift+click range extension for rendered table cells, plus
  selected-cell
  text insert/delete/clear/copy/cut/paste, tab/newline multi-cell paste,
  cell text offset hit testing, Arrow/Tab/Enter keyboard handling for selected
  table cells, F5 selected-cell edit entry, Esc return from active cell text
  editing to cell selection, Arrow/Shift+Arrow object nudging, and Shift+drag
  aspect-ratio preserving object resize. Insert/Overwrite input mode toggles
  with the Insert key, and overwrite typing replaces body and active table cell
  text through Rust delete/insert commands. Text input, paste, tab input, and
  keyboard delete
  defer page SVG refresh so normal typing does not reload the rendered page
  after every keystroke. Text-input commits stay in a Flutter overlay while the
  editor still has focus, even if `TextInputAction.done` or connection-close
  events arrive; `editRefreshDelay` starts only after the active input session
  is released. On desktop, transient focus/IME churn, including temporary
  external primary-focus changes during a text commit, gets a short grace window
  before deferred page refresh is released. Rapid input commits are queued while
  previous edit commands finish.
  Committed text is shown through a
  temporary Flutter overlay with a pending caret until the refreshed page render
  completes, including table cell text input. Deleted body text is temporarily
  masked until the refreshed page render completes. The example app uses a 5 s
  refresh delay for a steadier typing feel on large HWP files and defers HWP
  snapshot export until the user saves/exports or switches from the native
  editor to the full editor.
  Pending text previews are updated through a scoped overlay notifier, so
  normal typing updates the caret/text preview without rebuilding the whole
  native editor surface. Viewer controller notifications are scoped so cursor
  updates during typing do not rebuild the page viewport unless zoom changes.
  The status bar reports body cursor, active table cell,
  and selected object context. The view ribbon also includes a paragraph mark toggle
  that paints paragraph-end markers from page layer tree text runs.
- `rust/vendor/rhwp` should be committed. `rust/target` should stay ignored.

## License

MIT. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for bundled source and
dependency notices.
