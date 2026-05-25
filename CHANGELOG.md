## 2026.5.24

* Initial flutter_rhwp plugin scaffold.
* Added flutter_rust_bridge v2 Rust bridge with vendored rhwp v0.7.12.
* Added Dart APIs for opening bytes, rendering SVG, extracting text/Markdown,
  exporting HWP/HWPX/PDF, and applying basic text commands.
* Added RhwpViewer, an initial RhwpEditor overlay, and an example app with
  open/save/export workflows.
* Added facade tests against the vendored blank HWP sample, DOCX package
  output, and explicit unsupported exceptions for Web/WASM PDF export.
* Added HWP/HWPX export reopen checks for both the vendored blank sample and
  the bundled example asset.
* Strengthened native PDF export tests with structural PDF checks and a fast
  multi-page SVG-to-PDF regression case.
* Verified the FRB Web/WASM build path and patched vendored rhwp's standalone
  WASM startup and web-sys canvas style compatibility for FRB integration.
* Updated package metadata links for `JAICHANGPARK/flutter_rhwp`.
* Added a bundled example HWP asset and wired the example app to open it by
  default while keeping file picker and export/save workflows.
* Added text, Markdown, and SVG to the public Dart export surface and example
  export menu.
* Implemented initial DOCX export as a valid Word OOXML package generated from
  extracted document text, and exposed it in the example export menu.
* Added a Web-only `RhwpWebEditor` embed for upstream `@rhwp/editor`, plus an
  example app toggle between the Flutter bridge editor and the upstream Web
  editor.
* Added `RhwpWebEditorController` so Web editor mode can export bytes from the
  upstream editor state instead of the stale Flutter bridge document.
* Added a Web COOP/COEP service worker bootstrap for local FRB WASM debugging.
* Use the FRB process loader on iOS/macOS so the statically linked Rust library
  can be resolved inside Flutter apps.
* Removed incomplete Apple SwiftPM manifests so iOS/macOS builds use the
  CocoaPods podspec/cargokit path that links the Rust static library.
* Added Linux desktop example integration tests for opening the bundled HWP
  asset, rendering SVG, extracting text/Markdown, and exporting supported
  formats.
* Run Linux desktop integration tests under Xvfb in CI for headless GitHub
  Actions runners.
* Added macOS desktop example integration tests to CI for the bundled asset
  open/render/export workflow.
* Added Windows desktop example integration tests to CI for the bundled asset
  open/render/export workflow.
* Added Android emulator example integration tests to CI for the bundled asset
  open/render/export workflow.
* Added GitHub Actions CI for Rust/Dart checks, Web WASM build, desktop builds,
  and Android/iOS example builds.
* Added a custom `RhwpViewer` SVG builder hook and Flutter widget paint tests
  for viewer rendering, zoom, and editor overlay command flows.
* Added a `RhwpViewer` page virtualization regression test for lazy SVG page
  rendering during scroll.
* Added a Flutter-drawn `RhwpEditor` command-target caret and selection marker
  with widget coverage for collapsed and expanded selection states.
* Changed the example Web app to default to upstream Web editor mode so HWP
  open/edit/export can run without eager FRB WASM initialization on startup.
* Added example Web widget tests to CI so the browser editor mode shell is
  verified before the FRB WASM build.
* Added an iOS simulator CI helper and mobile workflow step for the example
  bundled asset open/render/export integration test.
* Added a generated FRB bridge mock smoke test for the Dart Rust API entrypoint.
* Improved DOCX export to use extracted Markdown and emit heading and simple
  table OOXML instead of only plain paragraph runs.
* Added root third-party notices for the vendored rhwp core, Cargokit, direct
  Dart/Rust dependencies, and generated FRB bridge files.
* Added a Web widget smoke test for bundled sample auto-open in upstream Web
  editor mode without eager Flutter bridge WASM initialization, and made empty
  Web editor module URLs render an inline message without injecting a bootstrap
  script.
* Added a typed Dart page layer tree model on top of rhwp's raw page layer tree
  JSON so editor/viewer code can inspect text nodes and bounds without ad hoc
  JSON traversal.
* Added text-run geometry helpers for page layer trees and made `RhwpEditor`
  prefer layer-tree caret/selection bounds when first-page text run geometry is
  available.
* Added a page-local `RhwpViewer.pageOverlayBuilder` hook and moved
  `RhwpEditor` caret/selection painting onto each rendered page so visible page
  overlays stay aligned with viewer scrolling and page layout.
