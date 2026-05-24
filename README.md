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
- Edit through an initial `RhwpEditor` command overlay.
- Embed upstream `@rhwp/editor` on Web with `RhwpWebEditor`.
- Example app workflows for opening the bundled asset sample or a picked
  HWP/HWPX file, toggling between the Flutter bridge viewer/editor and the
  upstream Web editor, then saving HWP/HWPX/PDF/DOCX/TXT/MD.

Not complete yet:

- DOCX export currently maps extracted text into paragraph-oriented OOXML.
  Table, image, and exact layout mapping are still pending.
- PDF export on Web/WASM throws `RhwpUnsupportedPlatformException`.
- Web requires the FRB WASM build step and generated `pkg/` output.
- `RhwpWebEditor` loads `@rhwp/editor` from a configurable ESM URL. Production
  apps should host or bundle that module instead of relying on a public CDN.
- Apple SwiftPM packaging still needs Rust build/linkage work. The podspec
  path uses cargokit, and the Dart loader is prepared for static linkage, but
  the generated SwiftPM package does not yet include the Rust archive.
- The Flutter-native editor UI is not implemented beyond command application.

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
RhwpWebEditor(
  initialBytes: bytes,
  fileName: 'sample.hwp',
)
```

`RhwpWebEditor` is a Web-only embed for upstream
[`@rhwp/editor`](https://www.npmjs.com/package/@rhwp/editor). It complements
the FRB bridge: use the Flutter bridge for a consistent cross-platform API, and
switch to the upstream Web editor when a browser app needs the full iframe-based
editing UI. The module URL defaults to `https://esm.sh/@rhwp/editor`; pass
`moduleUrl` to point at a locally bundled or self-hosted ESM build.

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
- Example Linux desktop integration tests for bundled asset open/render/export
  scenarios.
- FRB WASM bundle generation followed by `flutter build web`.
- Desktop example builds for Linux, macOS, and Windows.
- Mobile example builds for Android and iOS without code signing.
