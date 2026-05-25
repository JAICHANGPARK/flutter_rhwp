## 2026.5.25

* Updated plugin release metadata for the `2026.5.25` release.
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
* Extended page layer tree selection geometry to span multiple paragraphs and
  wired `RhwpEditor` page overlays to render those page-local selection rects.
* Added a Rust facade regression test for the page layer tree JSON contract that
  Flutter editor geometry depends on.
* Added `RhwpExportedDocument` and `RhwpDocument.exportDocument()` so save and
  download flows can use the same bytes, file name, extension, and MIME
  metadata contract across the Flutter bridge and example app.
* Added `RhwpWebEditorController.exportDocument()` so upstream Web editor mode
  can use the same export artifact metadata contract as the Flutter bridge.
* Documented the Rust vendoring policy: commit `rust/vendor/rhwp` for
  reproducible builds, but keep generated `rust/target` output ignored.
* Verified that the example Web release build completes after the Web editor
  default-mode and export artifact changes.
* Added Dart API documentation for export artifact metadata and Web editor
  controller export methods.
* Relaxed the `flutter_rust_bridge` dependency constraint to a caret range and
  recorded the current `flutter pub publish --dry-run` warnings.
* Added `.pubignore` so repository work logs remain in `docs/` without being
  published in the runtime package archive.
* Added bundled asset integration coverage for native PDF export metadata and
  PDF byte structure, while keeping Web/WASM on the explicit unsupported path.
* Added `RhwpFullEditor` as the public full-editor surface backed by upstream
  `@rhwp/editor`, and introduced `RhwpCommandEditor` to make the Flutter-native
  command overlay's limited role explicit.
* Backed native `RhwpFullEditor` with `webview_all` so the upstream editor can
  be hosted on Android, iOS, macOS, Windows, and Linux instead of being limited
  to Web.
* Updated the Linux example runner to host Flutter in a `GtkOverlay`, matching
  the platform view setup required by `webview_all`'s Linux WebKitGTK
  implementation.
* Added the WebKitGTK 4.1 development package to Linux CI dependencies for the
  full-editor WebView host.
* Raised the Flutter SDK lower bound to 3.35.0 to match the native full-editor
  WebView host dependency.
* Added macOS outgoing network entitlements to the example app so WKWebView can
  load the upstream editor module in sandboxed debug/profile/release runs.
* Added a Flutter-side loading/error overlay for native `RhwpFullEditor` so
  WebView bootstrap failures do not appear as a blank black panel.
* Fixed upstream editor file injection by using `@rhwp/editor`'s documented
  `loadFile(data, fileName)` API, and added `getPageSvg()` as the SVG export
  method for full-editor mode.
* Simplified README around package purpose, installation, quick start, usage,
  example, notes, and license.
* Added ArrowUp/ArrowDown paragraph navigation with Shift selection extension
  in the Flutter-native editor.
* Added Tab key text insertion in the Flutter-native editor, including
  replacement of active text selections.
* Changed Flutter-native ArrowUp/ArrowDown movement to prefer page-layer text
  run geometry before falling back to paragraph order.
* Changed Flutter-native Home/End movement to use page-layer line geometry
  before falling back to paragraph boundaries.
* Added Ctrl/Option+Arrow word navigation with Shift selection extension in the
  Flutter-native editor.
* Added Ctrl/Option+Backspace/Delete word deletion in the Flutter-native
  editor.
* Added PageUp/PageDown page-level keyboard navigation with Shift selection
  extension in the Flutter-native editor.
* Added `RhwpNativeEditor` as the 100% Flutter widget editor track while
  keeping `RhwpFullEditor` as the WebView/upstream editor fallback.
* Reworked the Flutter-native editor surface with a Flutter toolbar, menu tabs,
  page viewport, caret/selection overlay, status bar, and basic insert/delete
  command flow.
* Updated the example editor toggle from `Commands` to `Native editor`.
* Added page-layer text hit testing so the Flutter-native editor can move the
  caret by tapping rendered document text.
* Wired Flutter-native drag selection to the same page-layer hit-test model.
* Added Flutter-native editor keyboard handling for left/right/home caret
  movement, shift-selection, and backspace/delete command dispatch.
* Added a Flutter `TextInputClient` bridge so the native editor can receive IME
  text composition and commit finalized text through the Rust insert command.
* Added a Flutter-native composing preview overlay so active IME composition is
  visible near the caret before it is committed to the document.
* Added page-layer selection text extraction plus Flutter-native editor
  copy/cut/paste shortcuts and toolbar actions.
* Added `splitParagraph` to the Rust bridge command surface and wired
  Flutter-native Enter/Shift+Enter handling.
* Added `deleteRange` to the Rust bridge command surface and wired
  Flutter-native multi-paragraph selection replacement.
* Added `applyCharFormat` to the Rust bridge command surface and wired
  Flutter-native bold, italic, and underline toolbar/shortcut actions.
* Added `applyCharFormatRange` for same-section multi-paragraph character
  formatting in the Flutter-native editor.
* Added `applyParaFormat` and `applyParaFormatRange` for paragraph alignment,
  with Flutter-native toolbar buttons for left, center, right, and justify.
* Added `insertTable` to the Rust bridge command surface and wired a
  Flutter-native toolbar table insertion action.
* Added table row/column insert and delete commands to the Rust bridge surface
  with Flutter-native toolbar actions.
* Added table cell merge and split commands to the Rust bridge surface with
  Flutter-native toolbar actions.
* Added page-layer table cell hit testing so `RhwpNativeEditor` can fill table
  edit context from tapped rendered cells.
* Added Flutter-native table cell selection state and page overlay highlighting
  for tapped rendered cells.
* Added drag-based table cell range selection in `RhwpNativeEditor`, including
  multi-cell overlay highlighting and merge command context updates.
* Added selected table cell text insert/delete commands through the Rust bridge
  and wired `RhwpNativeEditor` text input to the active cell.
* Added table cell text source parsing and hit testing so tapping rendered cell
  text sets the active cell edit offset.
* Added Arrow and Tab keyboard navigation for selected table cells in the
  Flutter-native editor, including Shift+Arrow range extension.
* Added Escape handling in the Flutter-native editor to clear composing input,
  selected table cells, selected text, and active search highlights.
* Split the Flutter-native editor toolbar into HWP-style ribbon tabs for file,
  edit, view, input, format, page, table, and tools, with table cell selection
  opening the table ribbon context.
* Added a Flutter-native secondary-click context menu for text selection,
  clipboard, formatting, paragraph alignment, table insertion, and selected
  table cell actions.
* Exposed strikethrough, font size, and text color character-format properties
  in the Dart command surface, and added a Flutter-native character shape dialog
  that applies those values through the Rust bridge.
* Exposed line spacing, line spacing type, indent, and paragraph margin
  properties in the Dart paragraph-format command surface, and added a
  Flutter-native paragraph shape dialog that applies those values through the
  Rust bridge.
* Added Flutter-native text search in `RhwpNativeEditor`, using page layer tree
  text runs to select and highlight matches without calling the upstream Web
  editor.
* Added viewer page navigation to `RhwpViewerController`, wired the
  Flutter-native editor view ribbon to previous/next page controls, and made
  search result selection request the matching page.
* Added file-ribbon export actions to `RhwpNativeEditor` so HWP, HWPX, and PDF
  save artifacts can be emitted through a Flutter callback without using the
  upstream Web editor.
* Added synchronized zoom controls to the Flutter-native editor view ribbon and
  status bar, backed by the shared `RhwpEditorController` zoom state.
* Added Ctrl/Cmd zoom shortcuts to the Flutter-native editor for zoom in, zoom
  out, and reset zoom.
* Added file-open callback support to `RhwpNativeEditor` and wired the example
  app so the native editor file ribbon can launch the same file picker and save
  callbacks as the outer app toolbar.
* Added header/footer creation commands to the Dart/Rust bridge and enabled the
  Flutter-native editor page ribbon Header/Footer buttons.
* Added snapshot commands to the Dart/Rust bridge and wired `RhwpNativeEditor`
  edit-ribbon undo/redo to rhwp core snapshots.
* Added active search-match replace to the Flutter-native editor tools ribbon,
  using undo-aware delete/insert commands through the Rust bridge.
* Added replace-all to the Flutter-native editor tools ribbon, applying all
  current search matches in one undo-aware edit transaction.
* Added Flutter-native select-all through the edit ribbon, context menu, and
  Ctrl/Cmd+A shortcut using page layer tree source positions.
* Added End and Shift+End keyboard navigation to move or extend selection to
  the current paragraph end from page layer tree source positions.
* Added Ctrl/Cmd+F handling in `RhwpNativeEditor` to open the tools ribbon and
  focus the Flutter-native search field.
* Added F3 and Shift+F3 search result navigation shortcuts for the
  Flutter-native editor.
* Added Ctrl/Cmd+Home and Ctrl/Cmd+End document boundary navigation, including
  Shift selection extension, using page layer tree source positions.
