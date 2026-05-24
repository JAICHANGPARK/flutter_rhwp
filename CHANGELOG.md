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
* Added a Web COOP/COEP service worker bootstrap for local FRB WASM debugging.
* Use the FRB process loader on iOS/macOS so the statically linked Rust library
  can be resolved inside Flutter apps.
* Added Linux desktop example integration tests for opening the bundled HWP
  asset, rendering SVG, extracting text/Markdown, and exporting supported
  formats.
* Added GitHub Actions CI for Rust/Dart checks, Web WASM build, desktop builds,
  and Android/iOS example builds.
* Added a custom `RhwpViewer` SVG builder hook and Flutter widget paint tests
  for viewer rendering, zoom, and editor overlay command flows.
