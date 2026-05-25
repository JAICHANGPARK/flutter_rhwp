# flutter_rhwp

Flutter plugin for reading, viewing, editing, saving, and exporting HWP/HWPX
documents.

- Repository: [JAICHANGPARK/flutter_rhwp](https://github.com/JAICHANGPARK/flutter_rhwp)
- Rust core: [edwardkim/rhwp](https://github.com/edwardkim/rhwp), vendored at
  `rust/vendor/rhwp`
- Bridge: `flutter_rust_bridge` v2
- Version: `2026.5.25`

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
RhwpNativeEditor(document: document)
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
  hit testing, caret/drag-selection overlay, keyboard caret movement, IME
  composing preview, context menus, text commit, copy/cut/paste, Enter
  paragraph splitting, Shift+Enter soft line breaks, multi-paragraph selection
  replacement, multi-paragraph selected-text bold/italic/underline/strike
  formatting, a character shape dialog for font size and text color, paragraph
  alignment commands, a paragraph shape dialog for line spacing, indent, and
  paragraph margins, and basic text/table insert/delete plus table row/column
  and cell merge/split command flow with table-cell hit testing, selected-cell
  highlighting, and drag range selection for rendered table cells, plus
  selected-cell text insert/delete and cell text offset hit testing.
- `rust/vendor/rhwp` should be committed. `rust/target` should stay ignored.

## License

MIT. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for bundled source and
dependency notices.
