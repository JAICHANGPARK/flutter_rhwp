# flutter_rhwp

Flutter bindings and widgets for HWP/HWPX documents, built with
`flutter_rust_bridge` v2.

Repository: [`JAICHANGPARK/flutter_rhwp`](https://github.com/JAICHANGPARK/flutter_rhwp)

Rust core: upstream [`edwardkim/rhwp`](https://github.com/edwardkim/rhwp),
vendored at v0.7.12 for reproducible plugin builds.

## Status

This package is an initial plugin scaffold. It already wires Flutter to a
vendored `rhwp` v0.7.12 Rust crate through FRB opaque sessions.

Implemented:

- Open HWP/HWPX bytes.
- Read page count and document metadata.
- Render pages as SVG.
- Read page layer tree JSON.
- Extract text and Markdown.
- Export HWP, HWPX, native PDF, DOCX, text, Markdown, and page SVG.
- Apply basic edit commands for body text insert/delete and file name updates.
- Display pages with `RhwpViewer`.
- Edit through an initial `RhwpEditor` command overlay with a Flutter-drawn
  command-target caret and selection marker.
- Embed upstream `@rhwp/editor` on Web with `RhwpWebEditor` and
  `RhwpWebEditorController`.
- Example app workflows for opening the bundled asset sample or a picked
  HWP/HWPX file, toggling between the Flutter bridge viewer/editor and the
  upstream Web editor, then saving HWP/HWPX/PDF/DOCX/TXT/MD/SVG.
- On Web, the example opens files in upstream Web editor mode by default so the
  browser editor can run even before the FRB WASM bridge is initialized.

Not complete yet:

- DOCX export currently maps extracted text into paragraph-oriented OOXML.
  Table, image, and exact layout mapping are still pending.
- Flutter bridge PDF export on Web/WASM throws
  `RhwpUnsupportedPlatformException`. In Web editor mode, export support depends
  on the methods exposed by the loaded upstream `@rhwp/editor` build.
- Web requires the FRB WASM build step and generated `pkg/` output.
- `RhwpWebEditor` loads `@rhwp/editor` from a configurable ESM URL. Production
  apps should host or bundle that module instead of relying on a public CDN.
- Apple builds currently use the CocoaPods podspec/cargokit path for Rust
  static library linkage. SwiftPM manifests are intentionally omitted until the
  Rust build/linkage path is implemented for Swift Package Manager.
- The Flutter-native editor UI still uses command-target coordinates. Exact
  document layout-aware caret and selection mapping is pending.

## Usage

```dart
import 'dart:io';

import 'package:flutter_rhwp/flutter_rhwp.dart';

final bytes = await File('sample.hwp').readAsBytes();
final document = await Rhwp.open(bytes, fileName: 'sample.hwp');

final pageCount = await document.pageCount;
final firstPageSvg = await document.renderPageSvg(0);
final text = await document.extractText();
final hwpBytes = await document.export(RhwpExportFormat.hwp);
final svgBytes = await document.exportPageSvg(page: 0);
final markdownBytes = await document.exportMarkdown();

await document.close();
```

Viewer:

```dart
RhwpViewer(document: document)
```

Editor:

```dart
RhwpEditor(document: document)
```

Web editor:

```dart
final webEditorController = RhwpWebEditorController();

RhwpWebEditor(
  controller: webEditorController,
  initialBytes: bytes,
  fileName: 'sample.hwp',
);

final editedHwp = await webEditorController.exportHwp();
```

`RhwpWebEditor` is a Web-only embed for upstream
[`@rhwp/editor`](https://www.npmjs.com/package/@rhwp/editor). It complements
the FRB bridge: use the Flutter bridge for a consistent cross-platform API, and
switch to the upstream Web editor when a browser app needs the full iframe-based
editing UI. The module URL defaults to `https://esm.sh/@rhwp/editor`; pass
`moduleUrl` to point at a locally bundled or self-hosted ESM build. The
controller tries the upstream editor's exported methods such as `exportHwp`,
`exportHwpx`, `exportPdf`, `exportDocx`, `exportText`, `exportMarkdown`, and
`exportSvg`; if a method is missing, it throws `RhwpUnsupportedPlatformException`
with the upstream error message.

The example app starts in upstream Web editor mode on Web. Switching to
`Flutter` mode opens the same bytes through the FRB bridge; if the browser is
not cross-origin isolated or the WASM bundle is missing, the Web editor remains
usable while the Flutter bridge reports the load error.

Editing command:

```dart
await document.apply(
  RhwpCommand.insertText(
    section: 0,
    paragraph: 0,
    offset: 0,
    text: 'Hello',
  ),
);
```

## Rust

The Rust crate lives in `rust/`. The pinned upstream source is vendored at
`rust/vendor/rhwp`, so normal builds do not fetch `rhwp` from GitHub.

Regenerate bridge code after changing `rust/src/api`:

```sh
flutter_rust_bridge_codegen generate
```

Build the example Web WASM bundle:

```sh
rustup target add wasm32-unknown-unknown
rustup component add rust-src --toolchain nightly
cargo install wasm-pack --locked
flutter_rust_bridge_codegen build-web --dart-root . --rust-root rust -o "$PWD/example/web"
(cd example && flutter build web)
```

Use an absolute `-o` path, or a path relative to `rust/`, because `wasm-pack`
resolves the output directory from the Rust crate root.

The example Web app registers `example/web/coi-serviceworker.js` so local Web
debugging can enable COOP/COEP headers required by FRB's atomics-based WASM
bundle. If you run with a self-hosted upstream editor module:

```sh
cd example
flutter run -d chrome \
  --dart-define=RHWP_EDITOR_MODULE_URL=http://localhost:7700/path/to/editor.js
```

Run checks:

```sh
cargo check --manifest-path rust/Cargo.toml
cargo test --manifest-path rust/Cargo.toml
flutter analyze
flutter test
(cd example && flutter test)
```

The example app adds `file_picker` for user-selected file open/save flows. On
macOS the example enables user-selected read/write sandbox entitlement.

## CI

GitHub Actions runs the same checks in `.github/workflows/ci.yml`:

- Rust facade tests and Flutter analyze/unit tests.
- Dart unit tests include a generated FRB bridge mock smoke test.
- Example Linux, macOS, and Windows desktop integration tests for bundled asset
  open/render/export scenarios.
- Example Android emulator integration tests for the bundled asset
  open/render/export workflow.
- Example iOS simulator integration tests for the bundled asset
  open/render/export workflow.
- Example Web widget tests for the upstream Web editor default mode and browser
  mode toggle.
- FRB WASM bundle generation followed by `flutter build web`.
- Desktop example builds for Linux, macOS, and Windows.
- Mobile example builds for Android and iOS without code signing, followed by
  Android emulator and iOS simulator integration workflows.
